##[

###########################################
SQL Query Generation for PostgreSQL Backend
###########################################

Procs to generate SQL queries to modify tables and records.
]##

import strutils, macros
import db_postgres

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

  result = case $fieldRepr.typ
    of "int", "Positive", "Natural": "INTEGER"
    of "string": "TEXT"
    of "float": "REAL"
    of "bool": "BOOLEAN"
    of "DateTime": "TIMESTAMP WITH TIME ZONE"
    else: "TEXT"

  for prag in fieldRepr.signature.pragmas:
    if prag.name == "dbType" and prag.kind == pkKval:
      return $prag.value

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
          ", FOREIGN KEY ($#) REFERENCES $# (id)" % [fieldRepr.getColumn(),
                                                      dbObjReprs.getByName($prag.value).getTable()]
        of nnkDotExpr:
          ", FOREIGN KEY ($#) REFERENCES $# ($#)" % [fieldRepr.getColumn(),
                                                      dbObjReprs.getByName($prag.value[0]).getTable(),
                                                      $prag.value[1]]
        else: ""
    elif prag.name == "onDelete" and prag.kind == pkKval:
      result.add " ON DELETE $#" % $prag.value
    elif prag.name == "onUpdate" and prag.kind == pkKval:
      result.add " ON UPDATE $#" % $prag.value

proc genTableSchema(dbObjRepr: ObjRepr, dbObjReprs: openArray[ObjRepr]): SqlQuery =
  ## Generate table schema for an object representation.

  var tableSchema: string

  tableSchema.add "CREATE TABLE $# (\n" % dbObjRepr.getTable()

  var columns: seq[string]

  for field in dbObjRepr.fields:
    columns.add "\t$#" % genColStmt(field, dbObjReprs)

  tableSchema.add columns.join(",\n")
  tableSchema.add "\n)"

  result = sql tableSchema

proc genTableSchemas*(dbObjReprs: openArray[ObjRepr]): seq[SqlQuery] =
  ## Generate table schemas for a list of object representations.

  for dbObjRepr in dbObjReprs:
    result.add genTableSchema(dbObjRepr, dbObjReprs)

proc genDropTableQueries*(dbObjReprs: seq[ObjRepr]): seq[SqlQuery] =
  ## Generate ``DROP TABLE`` queries for a list of object representations.

  for dbObjRepr in dbObjReprs:
    result.add sql "DROP TABLE IF EXISTS $# CASCADE" % dbObjRepr.getTable()

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

