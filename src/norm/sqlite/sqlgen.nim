##[

#######################################
SQL Query Generation for SQLite Backend
#######################################

Procs to generate SQL queries to modify tables and records.
]##

import strutils, sequtils, macros
import ndb/sqlite

import ../objutils, ../pragmas


proc `$`*(query: SqlQuery): string = $ string query

proc getTable*(objRepr: ObjRepr): string =
  ##[ Get the name of the DB table for the given object representation:
  ``table`` pragma value if it exists or lowercased type name otherwise.
  ]##

  result = objRepr.signature.name.toLowerAscii()

  for prag in objRepr.signature.pragmas:
    if prag.name == "table" and prag.kind == pkKval:
      return $prag.value

proc getTable*(T: typedesc): string =
  ##[ Get the name of the DB table for the given type: ``table`` pragma value if it exists
  or lowercased type name otherwise.
  ]##

  when T.hasCustomPragma(table): T.getCustomPragmaVal(table)
  else: ($T).toLowerAscii()

proc getColumn*(fieldRepr: FieldRepr): string =
  ##[ Get the name of DB column for a field: ``dbCol`` pragma value if it exists
  or field name otherwise.
  ]##

  result = fieldRepr.signature.name

  for prag in fieldRepr.signature.pragmas:
    if prag.name == "dbCol" and prag.kind == pkKval:
      return $prag.value

proc getColumns*(dbObjRepr: ObjRepr, force = false): seq[string] =
  ## Get DB column names for an object representation as a sequence of strings.

  for fieldRepr in dbObjRepr.fields:
    if force or "ro" notin fieldRepr.signature.pragmaNames:
      result.add fieldRepr.getColumn()

proc getColumns*(obj: object, force = false): seq[string] =
  ## Get DB column names for an object as a sequence of strings.

  for field, _ in obj.fieldPairs:
    if force or not obj.dot(field).hasCustomPragma(ro):
      when obj.dot(field).hasCustomPragma(dbCol):
        result.add obj.dot(field).getCustomPragmaVal(dbCol)
      else:
        result.add field

proc getDbType(fieldRepr: FieldRepr): string =
  ## SQLite-specific mapping from Nim types to SQL data types.

  for prag in fieldRepr.signature.pragmas:
    if prag.name == "dbType" and prag.kind == pkKval:
      return $prag.value

  result =
    if fieldRepr.typ.kind in {nnkIdent, nnkSym}:
      case $fieldRepr.typ
        of "int", "Positive", "Natural", "bool", "DateTime": "INTEGER NOT NULL"
        of "string": "TEXT NOT NULL"
        of "float": "REAL NOT NULL"
        else: "TEXT NOT NULL"
    elif fieldRepr.typ.kind == nnkBracketExpr and $fieldRepr.typ[0] == "Option":
      case $fieldRepr.typ[1]
        of "int", "Positive", "Natural", "bool", "DateTime": "INTEGER"
        of "string": "TEXT"
        of "float": "REAL"
        else: "TEXT"
    else: "TEXT NOT NULL"

proc genColStmt(fieldRepr: FieldRepr, dbObjReprs: openArray[ObjRepr]): string =
  ## Generate SQL column statement for a field representation.

  result.add fieldRepr.getColumn()
  result.add " "
  result.add getDbType(fieldRepr)

  for prag in fieldRepr.signature.pragmas:
    if prag.name == "pk" and prag.kind == pkFlag:
      result.add " PRIMARY KEY"
    elif prag.name == "unique" and prag.kind == pkFlag:
      result.add " UNIQUE"
    elif prag.name == "notNull" and prag.kind == pkFlag:
      result.add " NOT NULL"
    elif prag.name == "check" and prag.kind == pkKval:
      result.add " CHECK $#" % $prag.value
    elif prag.name == "default" and prag.kind == pkKval:
      result.add " DEFAULT $#" % $prag.value
    elif prag.name == "fk" and prag.kind == pkKval:
      expectKind(prag.value, {nnkIdent, nnkSym, nnkDotExpr})
      result.add case prag.value.kind
        of nnkIdent, nnkSym:
          " REFERENCES $# (id)" % [dbObjReprs.getByName($prag.value).getTable()]
        of nnkDotExpr:
          " REFERENCES $# ($#)" % [dbObjReprs.getByName($prag.value[0]).getTable(), $prag.value[1]]
        else: ""
    elif prag.name == "onUpdate" and prag.kind == pkKval:
      result.add " ON UPDATE $#" % $prag.value
    elif prag.name == "onDelete" and prag.kind == pkKval:
      result.add " ON DELETE $#" % $prag.value

proc genTableSchema(dbObjRepr: ObjRepr, dbObjReprs: openArray[ObjRepr]): string =
  ## Generate table schema for an object representation.

  var colStmts: seq[string]

  for fieldRepr in dbObjRepr.fields:
    colStmts.add "\t" & genColStmt(fieldRepr, dbObjReprs)

  result = colStmts.join(",\n")

proc genTableSchemas*(dbObjReprs: openArray[ObjRepr]): seq[(string, string, string)] =
  ##[ Generate table schemas for a list of object representations.

  Result is a sequence of triplets "typeName-tableName-tableSchema."
  ]##

  for dbObjRepr in dbObjReprs:
    result.add (dbObjRepr.signature.name, dbObjRepr.getTable(), genTableSchema(dbObjRepr, dbObjReprs))

proc genCreateTableQuery*(tableSchema, tableName: string): SqlQuery =
  ## Generate query to create a table given its name and schema.

  sql "CREATE TABLE $# (\n$#\n)" % [tableName, tableSchema]

proc genDropTableQuery*(tableName: string): SqlQuery =
  ## Generate query to drop a table given its name.

  sql "DROP TABLE IF EXISTS $#" % tableName

macro genRenameTableQuery*(T: typedesc, newName: string): untyped =
  ## Generate query to rename a table.

  expectKind(T, nnkSym)

  let query = "ALTER TABLE $# RENAME TO $#" % [T.getImpl().toObjRepr().getTable(), newName.strVal]

  result = quote do:
    `query`

macro genRenameColQuery*(field: typedesc, newName: string): untyped =
  ## Generate query to rename a column.

  let
    objRepr = field[0].getImpl().toObjRepr()
    fieldRepr = objRepr.fields.getByName($field[1])

    query = "ALTER TABLE $# RENAME COLUMN $# TO $#" % [objRepr.getTable(), fieldRepr.getColumn(),
                                                       newName.strVal]

  result = quote do:
    `query`

macro genCopyQuery*(S, D: typedesc): untyped =
  ## Generate query to copy data from one table to another.

  expectKind(S, nnkSym)
  expectKind(D, nnkSym)

  let
    (srcObjRepr, dstObjRepr) = (S.getImpl().toObjRepr(), D.getImpl().toObjRepr())
    cols = srcObjRepr.getColumns(force=true).filterIt(it in dstObjRepr.getColumns(force=true))

    query = "INSERT INTO $1 ($2) SELECT $2 FROM $3" % [dstObjRepr.getTable(), cols.join(", "),
                                                       srcObjRepr.getTable()]

  result = quote do:
    `query`

proc genInsertQuery*(obj: object, force: bool): SqlQuery =
  ## Generate ``INSERT`` query for an object.

  let
    fields = obj.getColumns(force)
    placeholders = '?'.repeat(fields.len)

  result = sql "INSERT INTO $# ($#) VALUES ($#)" % [type(obj).getTable(), fields.join(", "),
                                                    placeholders.join(", ")]

proc genGetOneQuery*(obj: object, condition: string): SqlQuery =
  ## Generate ``SELECT`` query to fetch a single record for an object.

  sql "SELECT $# FROM $# WHERE $#" % [obj.getColumns(force=true).join(", "),
                                      type(obj).getTable(), condition]

proc genGetManyQuery*(obj: object, condition: string): SqlQuery =
  ## Generate ``SELECT`` query to fetch multiple records for an object.

  sql "SELECT $# FROM $# WHERE $# LIMIT ? OFFSET ?" % [obj.getColumns(force=true).join(", "),
                                                       type(obj).getTable(), condition]

proc genUpdateQuery*(obj: object, force: bool): SqlQuery =
  ## Generate ``UPDATE`` query for an object.

  var fieldsWithPlaceholders: seq[string]

  for field in obj.getColumns(force):
    fieldsWithPlaceholders.add field & " = ?"

  result = sql "UPDATE $# SET $# WHERE id = ?" % [type(obj).getTable(),
                                                  fieldsWithPlaceholders.join(", ")]

proc genDeleteQuery*(obj: object): SqlQuery =
  ## Generate ``DELETE`` query for an object.

  sql "DELETE FROM $# WHERE id = ?" % type(obj).getTable()
