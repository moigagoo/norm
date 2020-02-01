## Procs to generate SQL queries to modify tables and records.

import strutils, macros
import ndb/postgres

import ../objutils, ../pragmas


proc `$`*(query: SqlQuery): string = $ string query

proc getTable*(objRepr: ObjRepr): string =
  ##[ Get the name of the DB table for the given object representation:
  ``table`` pragma value if it exists or lowercased type name otherwise.
  ]##

  result = objRepr.signature.name.toLowerAscii()

  for prag in objRepr.signature.pragmas:
    # TODO: Remove check for "table" along with deprecated ``table`` pragma
    if (prag.name == "table" or prag.name == "dbTable") and prag.kind == pkKval:
      return $prag.value

proc getTable*(T: typedesc): string =
  ##[ Get the name of the DB table for the given type: ``table`` pragma value if it exists
  or lowercased type name otherwise.
  ]##

  when T.hasCustomPragma(dbTable): T.getCustomPragmaVal(dbTable)
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

macro getColumns*(T: typedesc, force = false): untyped =
  let cols = T.getImpl().toObjRepr().getColumns(force=force.boolVal)

  result = newLit cols

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

  if fieldRepr.signature.name == "id" and $fieldRepr.typ == "int" and
    "pk" in fieldRepr.signature.pragmaNames:
      return "SERIAL"

  result =
    if fieldRepr.typ.kind in {nnkIdent, nnkSym}:
      case $fieldRepr.typ
        of "int", "int64", "Positive", "Natural": "INTEGER NOT NULL DEFAULT 0"
        of "string": "TEXT NOT NULL DEFAULT ''"
        of "float": "REAL NOT NULL DEFAULT 0.0"
        of "bool": "BOOLEAN NOT NULL DEFAULT FALSE"
        of "DateTime": "TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT '1970-01-01 00:00:00+00'"
        else: "TEXT NOT NULL DEFAULT ''"
    elif fieldRepr.typ.kind == nnkBracketExpr and $fieldRepr.typ[0] == "Option":
      case $fieldRepr.typ[1]
        of "int", "int64", "Positive", "Natural": "INTEGER"
        of "string": "TEXT"
        of "float": "REAL"
        of "bool": "BOOLEAN"
        of "DateTime": "TIMESTAMP WITH TIME ZONE"
        else: "TEXT"
    else: "TEXT NOT NULL DEFAULT ''"

  for prag in fieldRepr.signature.pragmas:
    if prag.name == "dbType" and prag.kind == pkKval:
      return $prag.value

proc genColStmt(fieldRepr: FieldRepr): string =
  ## Generate SQL column statement for a field representation.

  result.add fieldRepr.getColumn()
  result.add " "
  result.add getDbType(fieldRepr)

  for prag in fieldRepr.signature.pragmas:
    if prag.name == "pk" and prag.kind == pkFlag:
      result.add " PRIMARY KEY"
    elif prag.name == "unique" and prag.kind == pkFlag:
      result.add " UNIQUE"
    elif prag.name == "check" and prag.kind == pkKval:
      result.add " CHECK $#" % $prag.value
    elif prag.name == "fk" and prag.kind == pkKval:
      expectKind(prag.value, {nnkIdent, nnkSym, nnkDotExpr})
      result.add case prag.value.kind
        of nnkIdent, nnkSym:
          ", FOREIGN KEY ($#) REFERENCES $# (id)" % [fieldRepr.getColumn(), prag.value.getImpl().toObjRepr().getTable()]
        of nnkDotExpr:
          let
            refObjRepr = prag.value[0].getImpl().toObjRepr()
            refTable = refObjRepr.getTable()
            refCol = refObjRepr.fields.getByName($prag.value[1]).getColumn()

          ", FOREIGN KEY ($#) REFERENCES $# ($#)" % [fieldRepr.getColumn(), refTable, refCol]
        else: ""
    elif prag.name == "onDelete" and prag.kind == pkKval:
      result.add " ON DELETE $#" % $prag.value
    elif prag.name == "onUpdate" and prag.kind == pkKval:
      result.add " ON UPDATE $#" % $prag.value

proc genTableSchema(dbObjRepr: ObjRepr): string =
  ## Generate table schema for an object representation.

  var colStmts: seq[string]

  for fieldRepr in dbObjRepr.fields:
    colStmts.add "\t" & genColStmt(fieldRepr)

  result = colStmts.join(",\n")

macro genTableSchema*(T: typedesc): string =
  ## Generate table schema for a type.

  let tableSchema = genTableSchema(T.getImpl().toObjRepr())

  result = newLit tableSchema

proc genCreateTableQuery*(tableName, tableSchema: string): SqlQuery =
  ## Generate query to create a table.

  sql "CREATE TABLE $# (\n$#\n)" % [tableName, tableSchema]

macro genCreateTableQuery*(T: typedesc): string =
  ## Generate query to create a table from a type.

  let
    objRepr = T.getImpl().toObjRepr()
    query = "CREATE TABLE $# (\n$#\n)" % [objRepr.getTable(), genTableSchema(objRepr)]


  result = newLit query

proc genDropTableQuery*(tableName: string): SqlQuery =
  ## Generate query to drop a table given its name.

  sql "DROP TABLE IF EXISTS $# CASCADE" % tableName

macro genAddColQuery*(field: typedesc): untyped =
  ## Generate query to add column to table.

  expectKind(field, nnkDotExpr)

  let
    objRepr = field[0].getImpl().toObjRepr()
    fieldRepr = objRepr.fields.getByName($field[1])

    query = "ALTER TABLE $# ADD COLUMN $#" % [objRepr.getTable(), fieldRepr.genColStmt()]

  result = newLit query

proc genDropColsQuery*(T: typedesc, cols: openArray[string]): SqlQuery =
  ## Generate query to drop columns from table.

  var dropColStmts: seq[string]

  for col in cols:
    dropColStmts.add "DROP COLUMN IF EXISTS $# CASCADE" % col

  result = sql "ALTER TABLE $# $#" % [T.getTable(), dropColStmts.join(", ")]

macro genRenameColQuery*(field: typedesc, oldName: string): untyped =
  ## Generate query to rename a column.

  expectKind(field, nnkDotExpr)

  let
    objRepr = field[0].getImpl().toObjRepr()
    fieldRepr = objRepr.fields.getByName($field[1])

    query = "ALTER TABLE $# RENAME COLUMN $# TO $#" % [objRepr.getTable(), oldName.strVal, fieldRepr.getColumn()]

  result = newLit query

proc genRenameTableQuery*(oldName, newName: string): SqlQuery =
  ## Generate query to rename a table.

  sql "ALTER TABLE $# RENAME TO $#" % [oldName, newName]

template genCopyQuery*(T: typedesc, targetTable: string): SqlQuery =
  ## Generate query to copy data from one table to another.

  sql "INSERT INTO $1 ($2) SELECT $2 FROM $3" % [targetTable, T.getColumns(force=true).join(", "), T.getTable()]

proc genInsertQuery*(obj: object, force: bool): SqlQuery =
  ## Generate ``INSERT`` query for an object.

  let fields = obj.getColumns(force)

  var placeholders: seq[string]
  for i in 1..fields.len:
    placeholders.add "$" & $i

  result = sql "INSERT INTO $# ($#) VALUES ($#)" % [type(obj).getTable(), fields.join(", "),
                                                    placeholders.join(", ")]

proc genGetOneQuery*(obj: object, condition: string): SqlQuery =
  ## Generate ``SELECT`` query to fetch a single record for an object.

  sql "SELECT $# FROM $# WHERE $#" % [obj.getColumns(force=true).join(", "),
                                      type(obj).getTable(), condition]

proc genGetManyQuery*(obj: object, condition: string, paramCount = 0): SqlQuery =
  ## Generate ``SELECT`` query to fetch multiple records for an object.

  sql "SELECT $# FROM $# WHERE $# LIMIT $$$# OFFSET $$$#" % [
    obj.getColumns(force=true).join(", "),
    type(obj).getTable(),
    condition,
    $(paramCount+1),
    $(paramCount+2)
  ]

template genGetAllQuery*(T: typedesc, condition: string): SqlQuery =
  ## Generate ``SELECT`` query to fetch all records for an object.

  sql "SELECT $# FROM $# WHERE $#" % [T.getColumns(force=true).join(", "), T.getTable(), condition]

proc genUpdateQuery*(obj: object, force: bool): SqlQuery =
  ## Generate ``UPDATE`` query for an object.

  var fieldsWithPlaceholders: seq[string]

  for i, field in obj.getColumns(force):
    fieldsWithPlaceholders.add field & " = $$$#" % $(i+1)

  result = sql "UPDATE $# SET $# WHERE id = $$$#" % [
    type(obj).getTable(),
    fieldsWithPlaceholders.join(", "),
    $(len(fieldsWithPlaceholders)+1)
  ]

proc genDeleteQuery*(obj: object): SqlQuery =
  ## Generate ``DELETE`` query for an object.

  sql "DELETE FROM $# WHERE id = $$1" % type(obj).getTable()

