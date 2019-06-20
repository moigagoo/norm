##[

###############
MongoDB Backend
###############

]##

#
# Interpreting between BSON and Nim Objects
#
# From BSON to Nim Types:
#
# | BSON          | Type      | Notes
# | ------------- | --------- | ---------------------
# | Double        | float     | default float in Nim already 64-bit
# | String (UTF8) | string    | string already UTF-8
# | Oid           | Oid       | https://nim-lang.org/docs/oids.html
# | Bool          | bool      | 
# | TimeUTC       | timestamp | https://nim-lang.org/docs/times.html
# | Null          | Option[T] | Only fields of Option[T] can be null
# | Int32         | int       | ideally, int32, but it will convert to int, int32, or int64
# | Int64         | int       | ideally, int64, bit it will convert to int, int32, or int64
#
# NOT YET SUPPORTED
#
# | Document      | (Object)  | field points to another object type. the other object need not be "dressed" with `db`
# | Array         | seq[T]    | we ONLY support same-type arrays right now
# Array (heterogeneous lists not supported yet)
# DBPointer
# Binary
# Timestamp
#
# NOT SUPPORTED (ignored):
#
# Regexp
# JSCode
# JSCodeWithScope
# MaximumKey
# MinimumKey
#
# From Nim Object to BSON
#
# | Type      | BSON          | Notes
# | --------- | ------------- |---------------------
# | float     | Double        | default float in Nim already 64-bit
# | string    | String (UTF8) | string already UTF-8
# | Oid       | Oid           | https://nim-lang.org/docs/oids.html; all-zeroes count as a MISSING entry; not a null
# | bool      | Bool          | 
# | timestamp | TimeUTC       | https://nim-lang.org/docs/times.html; 1970-01-01 00:00:00 counts as MISSING; not null
# | Option[T] | Null          | Only fields of Option[T] can be null
# | int       | Int32         |
#
# NOT YET SUPPORTED (compile-time error generated):
#
# | float32   | Double        | 
# | float64   | Double        | default float in Nim already 64-bit
# | (Object)  | Document      | it is not possible to a "Missing" state. The closest analogue is Option[ObjectType]
# | seq[T]    | Array         | to support null, make it seq[Option[T]]
# | int32     | Int32         |
# | int64     | Int64         |
# Tuples
# Tables
#

import strutils, macros, typetraits, logging, options
import nimongo.bson
import nimongo.mongo
import oids
import times

import rowutils, objutils, pragmas


export strutils, macros, logging, options
export rowutils, objutils, pragmas
export bson
export mongo
export oids
export times

# proc `$`*(query: SqlQuery): string = $ string query

# proc getCollectionName*(objRepr: ObjRepr): string =
#   ##[ Get the name of the DB table for the given object representation:
#   ``table`` pragma value if it exists or lowercased type name otherwise.
#   ]##

#   result = objRepr.signature.name.toLowerAscii()

#   for prag in objRepr.signature.pragmas:
#     if prag.name == "table" and prag.kind == pkKval:
#       return $prag.value

proc getCollectionName*(T: typedesc): string =
  ##[ Get the name of the DB table for the given type: ``table`` pragma value if it exists
  or lowercased type name otherwise.
  ]##

  when T.hasCustomPragma(table): T.getCustomPragmaVal(table)
  else: ($T).toLowerAscii()  

# proc getColumn*(fieldRepr: FieldRepr): string =
#   ##[ Get the name of DB column for a field: ``dbCol`` pragma value if it exists
#   or field name otherwise.
#   ]##

#   result = fieldRepr.signature.name

#   for prag in fieldRepr.signature.pragmas:
#     if prag.name == "dbCol" and prag.kind == pkKval:
#       return $prag.value



# proc getDbType(fieldRepr: FieldRepr): string =
#   ## SQLite-specific mapping from Nim types to SQL data types.

#   for prag in fieldRepr.signature.pragmas:
#     if prag.name == "dbType" and prag.kind == pkKval:
#       return $prag.value

#   result =
#     if fieldRepr.typ.kind == nnkIdent:
#       case $fieldRepr.typ:
#       of "int": "INTEGER NOT NULL"
#       of "string": "TEXT NOT NULL"
#       of "float": "REAL NOT NULL"
#       else: "TEXT NOT NULL"
#     elif fieldRepr.typ.kind == nnkBracketExpr and $fieldRepr.typ[0] == "Option":
#       case $fieldRepr.typ[1]:
#       of "int": "INTEGER"
#       of "string": "TEXT"
#       of "float": "REAL"
#       else: "TEXT"
#     else: "TEXT NOT NULL"

# proc genColStmt(fieldRepr: FieldRepr, dbObjReprs: openArray[ObjRepr]): string =
#   ## Generate SQL column statement for a field representation.

#   result.add fieldRepr.getColumn()
#   result.add " "
#   result.add getDbType(fieldRepr)

#   for prag in fieldRepr.signature.pragmas:
#     if prag.name == "pk" and prag.kind == pkFlag:
#       result.add " PRIMARY KEY"
#     elif prag.name == "unique" and prag.kind == pkFlag:
#       result.add " UNIQUE"
#     elif prag.name == "notNull" and prag.kind == pkFlag:
#       result.add " NOT NULL"
#     elif prag.name == "check" and prag.kind == pkKval:
#       result.add " CHECK $#" % $prag.value
#     elif prag.name == "default" and prag.kind == pkKval:
#       result.add " DEFAULT $#" % $prag.value
#     elif prag.name == "fk" and prag.kind == pkKval:
#       expectKind(prag.value, {nnkIdent, nnkDotExpr})

#       result.add case prag.value.kind
#       of nnkIdent:
#         " REFERENCES $# (id)" % [dbObjReprs.getByName($prag.value).getTable()]
#       of nnkDotExpr:
#         " REFERENCES $# ($#)" % [dbObjReprs.getByName($prag.value[0]).getTable(), $prag.value[1]]
#       else: ""
#     elif prag.name == "onUpdate" and prag.kind == pkKval:
#       result.add " ON UPDATE $#" % $prag.value
#     elif prag.name == "onDelete" and prag.kind == pkKval:
#       result.add " ON DELETE $#" % $prag.value

# proc genTableSchema(dbObjRepr: ObjRepr, dbObjReprs: openArray[ObjRepr]): string =
#   ## Generate table schema for an object representation.

#   result.add "CREATE TABLE $# (\n" % dbObjRepr.getTable()

#   var columns: seq[string]

#   for field in dbObjRepr.fields:
#     columns.add "\t$#" % genColStmt(field, dbObjReprs)

#   result.add columns.join(",\n")
#   result.add "\n)"

# proc genTableSchemas*(dbObjReprs: openArray[ObjRepr]): seq[SqlQuery] =
#   ## Generate table schemas for a list of object representations.

#   for dbObjRepr in dbObjReprs:
#     result.add sql genTableSchema(dbObjRepr, dbObjReprs)

# proc genDropTableQueries*(dbObjReprs: seq[ObjRepr]): seq[SqlQuery] =
#   ## Generate ``DROP TABLE`` queries for a list of object representations.

#   for dbObjRepr in dbObjReprs:
#     result.add sql "DROP TABLE IF EXISTS $#" % dbObjRepr.getTable()

# proc genInsertQuery*(obj: object, force: bool): SqlQuery =
#   ## Generate ``INSERT`` query for an object.

#   let
#     fields = obj.getColumns(force)
#     placeholders = '?'.repeat(fields.len)

#   result = sql "INSERT INTO $# ($#) VALUES ($#)" % [type(obj).getTable(), fields.join(", "),
#                                                     placeholders.join(", ")]

# proc genGetOneQuery*(obj: object, condition: string): SqlQuery =
#   ## Generate ``SELECT`` query to fetch a single record for an object.

#   sql "SELECT $# FROM $# WHERE $#" % [obj.getColumns(force=true).join(", "),
#                                       type(obj).getTable(), condition]

# proc genGetManyQuery*(obj: object, condition: string): SqlQuery =
#   ## Generate ``SELECT`` query to fetch multiple records for an object.

#   sql "SELECT $# FROM $# WHERE $# LIMIT ? OFFSET ?" % [obj.getColumns(force=true).join(", "),
#                                                        type(obj).getTable(), condition]

# proc genUpdateQuery*(obj: object, force: bool): SqlQuery =
#   ## Generate ``UPDATE`` query for an object.

#   var fieldsWithPlaceholders: seq[string]

#   for field in obj.getColumns(force):
#     fieldsWithPlaceholders.add field & " = ?"

#   result = sql "UPDATE $# SET $# WHERE id = ?" % [type(obj).getTable(),
#                                                   fieldsWithPlaceholders.join(", ")]

# proc genDeleteQuery*(obj: object): SqlQuery =
#   ## Generate ``DELETE`` query for an object.

#   sql "DELETE FROM $# WHERE id = ?" % type(obj).getTable()


# | float     | Double        | default float in Nim already 64-bit
# | float32   | Double        | 
# | float64   | Double        | default float in Nim already 64-bit
# | string    | String (UTF8) | string already UTF-8
# | Oid       | Oid           | https://nim-lang.org/docs/oids.html; all-zeroes count as a MISSING entry; not a null
# | bool      | Bool          | 
# | Time      | TimeUTC       | https://nim-lang.org/docs/times.html; 1970-01-01 00:00:00 counts as MISSING; not null
# | Option[T] | Null          | Only fields of Option[T] can be null
# | int       | Int32         |
# | int32     | Int32         |
# | int64     | Int64         |


proc buildBSON*(obj: object, force = false): Bson =
  result = newBsonDocument()

  let fields = obj.getColumnRefs(force)

  for field in fields:
    case field.fieldType:
    of "float":
      result[field.fieldName] = toBson(parseFloat(field.fieldStrValue))
    of "string":
      result[field.fieldName] = toBson(field.fieldStrValue)
    of "Oid":
      if field.fieldStrValue == "000000000000000000000000":
        discard
      else:
        result[field.fieldName] = toBson(parseOid(field.fieldStrValue))
    of "bool":
      result[field.fieldName] = toBson(parseBool(field.fieldStrValue))
    of "Time":
      let temp = parseTime(field.fieldStrValue, "yyyy-MM-dd\'T\'HH:mm:sszzz", utc())
      if temp != fromUnix(0):
        result[field.fieldName] = toBson(parseTime(field.fieldStrValue, "yyyy-MM-dd\'T\'HH:mm:sszzz", utc()))
    of "int":
      result[field.fieldName] = toBson(parseInt(field.fieldStrValue))
    else:
      discard


template genWithDb(connection, user, password, database: string): untyped {.dirty.} =
  ## Generate ``withDb`` templates.

  template withCustomDb*(customConnection, customUser, customPassword, customDatabase: string,
                         body: untyped): untyped {.dirty.} =
    ##[ A wrapper for actions that require custom DB connection, i.e. not the one defined in ``db``.
    Defines CRUD procs to work with the DB.

    'connection' should contain the URI pointing to the MongoDB server.

    The 'user' and 'password' parameters are not used.

    'database' should contain the database shard.

    Aforementioned procs and procs defined in a ``db`` block can be used only
    in  a ``withDb`` block.
    ]##

    block:
      var dbConn = newMongoWithURI(customConnection)
      let
        dbConnResult = dbConn.connect()

      # there is no 'dropTables'; that is a VERY non-mongo thing to do

      # there is no 'createTables'; that is a VERY non-mongo thing to do

      template insert(obj: var object, force = false) {.used.} =
        ##[ Insert object instance as a document into DB.The object's id is updated after
        the insertion.

        The ``force`` parameter is ignored by the mongodb library.
        ]##

        let
          doc = buildBSON(obj, true)
          dbCollection = dbConn[customDatabase][getCollectionName(type(obj))]

        echo "collection: " & getCollectionName(type(obj))
        echo "doc before:"
        echo $doc

        var response = dbCollection.insert(doc)

        echo "response: " & $response

        if len(response.inserted_ids) > 0:
          obj.id = response.inserted_ids[0].toOid

        echo "doc after:"
        echo $buildBSON(obj, true)
        echo "object after:"
        echo $obj

#       template getOne(obj: var object, cond: string, params: varargs[DbValue, dbValue]) {.used.} =
#         ##[ Read a record from DB by condition and store it into an existing object instance.

#         If multiple records are found, return the first one.
#         ]##

#         let getOneQuery = genGetOneQuery(obj, cond)

#         debug getOneQuery, " <- ", params.join(", ")

#         let row = dbConn.getRow(getOneQuery, params)

#         if row.isNone():
#           raise newException(KeyError, "Record by condition '$#' with params '$#' not found." %
#                              [cond, params.join(", ")])

#         get(row).to(obj)

#       proc getOne(T: typedesc, cond: string, params: varargs[DbValue, dbValue]): T {.used.} =
#         ##[ Read a record from DB by condition into a new object instance.

#         If multiple records are found, return the first one.
#         ]##

#         result.getOne(cond, params)

#       template getOne(obj: var object, id: int) {.used.} =
#         ## Read a record from DB by id and store it into an existing object instance.

#         let getOneQuery = genGetOneQuery(obj, "id=?")

#         debug getOneQuery, " <- ", $id

#         let row = dbConn.getRow(getOneQuery, id)

#         if row.isNone():
#           raise newException(KeyError, "Record with id=$# not found." % $id)

#         get(row).to(obj)

#       proc getOne(T: typedesc, id: int): T {.used.} =
#         ## Read a record from DB by id into a new object instance.

#         result.getOne(id)

#       proc getMany(objs: var seq[object], limit: int, offset = 0,
#                    cond = "1", params: varargs[DbValue, dbValue]) {.used.} =
#         ##[ Read ``limit`` records with ``offset`` from DB into an existing open array of objects.

#         Filter using ``cond`` condition.
#         ]##

#         if len(objs) == 0: return

#         let
#           getManyQuery = genGetManyQuery(objs[0], cond)
#           params = @params & @[dbValue min(limit, len(objs)), dbValue offset]

#         debug getManyQuery, " <- ", params.join(", ")

#         let rows = dbConn.getAllRows(getManyQuery, params)

#         rows.to(objs)

#       proc getMany(T: typedesc, limit: int, offset = 0,
#                    cond = "1", params: varargs[DbValue, dbValue]): seq[T] {.used.} =
#         ##[ Read ``limit`` records  with ``offset`` from DB into a sequence of objects,
#         create the sequence on the fly.

#         Filter using ``cond`` condition.
#         ]##

#         result.setLen limit
#         result.getMany(limit, offset, cond, params)

#       template update(obj: object, force = false) {.used.} =
#         ##[ Update DB record with object field values.

#         By default, readonly fields are not updated. Use ``force=true`` to update all fields.
#         ]##

#         let
#           updateQuery = genUpdateQuery(obj, force)
#           params = obj.toRow(force) & dbValue obj.id

#         debug updateQuery, " <- ", params.join(", ")

#         dbConn.exec(updateQuery, params)

#       template delete(obj: var object) {.used.} =
#         ## Delete a record in DB by object's id. The id is set to 0 after the deletion.

#         let deleteQuery = genDeleteQuery(obj)

#         debug deleteQuery, " <- ", $obj.id

#         dbConn.exec(deleteQuery, obj.id)

#         obj.id = 0

      try:
        # let foreignKeyQuery {.genSym.} = sql "PRAGMA foreign_keys = ON"
        # debug foreignKeyQuery
        # dbConn.exec foreignKeyQuery
        body
      finally: discard

#   template withDb*(body: untyped): untyped {.dirty.} =
#     ##[ A wrapper for actions that require DB connection. Defines CRUD procs to work with the DB,
#     as well as ``createTables`` and ``dropTables`` procs.

#       Aforementioned procs and procs defined in a ``db`` block can be used only
#       in  a ``withDb`` block.
#     ]##

#     withCustomDb(connection, user, password, database):
#       body


proc ensureIdFields(typeSection: NimNode): NimNode =
  ## Check if ``id`` field is in the object definition, insert it if it's not.

  result = newNimNode(nnkTypeSection)

  for typeDef in typeSection:
    var objRepr = typeDef.toObjRepr()

    if "id" notin objRepr.fieldNames:
      let idField = FieldRepr(
        signature: SignatureRepr(
          name: "id",
          exported: true,
          pragmas: @[
            PragmaRepr(name: "pk", kind: pkFlag),
            PragmaRepr(name: "ro", kind: pkFlag),
            PragmaRepr(name: "dbCol", kind: pkKval, value: parseExpr("\"_id\""))
          ]
        ),
        typ: ident "Oid"
      )
      objRepr.fields.insert(idField, 0)

    result.add objRepr.toTypeDef()

# macro db*(connection, user, password, database: string, body: untyped): untyped =
#   ##[ DB models definition. Models are defined as regular Nim objects in regular ``type`` sections.

#   ``connection``, ``user``, ``password``, ``database`` are the same args accepted
#   by a standard ``dbConn`` instance.

#   The macro generates ``withDb`` template that wraps all DB interations.
#   ]##

#   result = newStmtList()

#   var dbObjReprs: seq[ObjRepr]

#   for node in body:
#     if node.kind == nnkTypeSection:
#       let typeSection = node.ensureIdFields()

#       result.add typeSection

#       for typeDef in typeSection:
#         dbObjReprs.add typeDef.toObjRepr()

#     else:
#       result.add node

#   let withDbNode = getAst genWithDb(connection, user, password, database,
#                                     genTableSchemas(dbObjReprs), genDropTableQueries(dbObjReprs))

#   result.insert(0, withDbNode)


macro db*(connection, user, password, database: string, body: untyped): untyped =
  ##[ DB models definition. Models are defined as regular Nim objects in regular ``type`` sections.

  ``connection``, ``user``, ``password``, ``database`` are the same args accepted by a standard ``dbConn`` instance.

  The macro generates ``withDb`` template that wraps all DB interations.
  ]##

  result = newStmtList()

  var dbObjReprs: seq[ObjRepr]

  for node in body:
    if node.kind == nnkTypeSection:
      let typeSection = node.ensureIdFields()

      result.add typeSection

      for typeDef in typeSection:
        dbObjReprs.add typeDef.toObjRepr()

    else:
      result.add node

  let withDbNode = getAst genWithDb(connection, user, password, database)

  result.insert(0, withDbNode)
