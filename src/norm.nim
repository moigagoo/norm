##[

###############
Norm, a Nim ORM
###############

Norm is an ORM for Nim that doesn't try to outsmart you. While lubricating the boring parts of working with DB, it won't try to solve complex problems that are best solved by humans anyway.

To use Norm, you need to learn just a few concepts:

- to define DB models, wrap a type section with objects in a ``db`` block
- to finetune the model, add pragmas to objects and fields
- to work with the DB, use ``withDB`` block
- for CRUD, use the predefined ``insert``, ``getOne``, ``getMany``, ``update``,
and ``delete`` procs
- to create tables, call ``createTables``, to drop tables call ``dropTables``

`Read the API docs → <https://moigagoo.github.io/norm/norm.html>`__

]##


import strutils, macros
import typetraits
import db_sqlite

import chronicles

import norm / [rowutils, objutils]


export strutils, macros
export chronicles
export rowutils, objutils


template pk* {.pragma.}
  ## Mark field as primary key. The special field ``id`` is mark with ``pk`` by default.

template ro* {.pragma.}
  ##[ Mark field as read-only.

  Read-only fields are ignored in ``insert`` and ``update`` unless ``force`` is passed.

  Use for fields that are populated automatically by the DB: ids, timestamps, and so on.
  The special field ``id`` is mark with ``pk`` by default.
  ]##

template fk*(val: untyped) {.pragma.}
  ##[ Mark field as foreign key another type. ``val`` is either a type or a "type.field"
  expression. If a type is provided, its ``id`` field is referenced.
  ]##

template dbType*(val: string) {.pragma.}
  ## DB native type to use in table schema.

template default*(val: string) {.pragma.}
  ## Default value for the DB column.

template notNull* {.pragma.}
  ## Add ``NOT NULL`` constraint.

template check*(val: string) {.pragma.}
  ## Add a ``CHECK <CONDITION>`` constraint.

template table*(val: string) {.pragma.}
  ## Set table name. Lowercased type name is used when unset.

proc getTable*(objRepr: ObjRepr): string =
  ##[ Get the name of the DB table for the given object representation:
  ``table`` pragma value if it exists or lowercased type name otherwise.
  ]##

  result = objRepr.signature.name.toLowerAscii()

  for prag in objRepr.signature.pragmas:
    if prag.name == "table" and prag.kind == pkKval:
      return $prag.value

proc getDbType(fieldRepr: FieldRepr): string =
  ## SQLite-specific mapping from Nim types to SQL data types.

  result = case $fieldRepr.typ
  of "int": "INTEGER"
  of "string": "TEXT"
  of "float": "REAL"
  else: "TEXT"

  for prag in fieldRepr.signature.pragmas:
    if prag.name == "dbType" and prag.kind == pkKval:
      return $prag.value

proc genColStmt(fieldRepr: FieldRepr, dbObjReprs: openarray[ObjRepr]): string =
  ## Generate SQL column statement for a field representation.

  result.add fieldRepr.signature.name
  result.add " "
  result.add getDbType(fieldRepr)

  for prag in fieldRepr.signature.pragmas:
    if prag.name == "pk" and prag.kind == pkFlag:
      result.add " PRIMARY KEY"
    elif prag.name == "notNull" and prag.kind == pkFlag:
      result.add " NOT NULL"
    elif prag.name == "check" and prag.kind == pkKval:
      result.add " CHECK $#" % $prag.value
    elif prag.name == "default" and prag.kind == pkKval:
      result.add " DEFAULT $#" % $prag.value
    elif prag.name == "fk" and prag.kind == pkKval:
      expectKind(prag.value, {nnkIdent, nnkDotExpr})

      result.add case prag.value.kind
      of nnkIdent:
        ", FOREIGN KEY ($#) REFERENCES $# (id)" % [fieldRepr.signature.name,
                                                    dbObjReprs.getByName($prag.value).getTable()]
      of nnkDotExpr:
        ", FOREIGN KEY ($#) REFERENCES $# ($#)" % [fieldRepr.signature.name,
                                                    dbObjReprs.getByName($prag.value[0]).getTable(),
                                                    $prag.value[1]]
      else: ""

proc genTableSchema(dbObjRepr: ObjRepr, dbObjReprs: openarray[ObjRepr]): string =
  ## Generate table schema for an object representation.

  result.add "CREATE TABLE $# (\n" % dbObjRepr.getTable()

  var columns: seq[string]

  for field in dbObjRepr.fields:
    columns.add "\t$#" % genColStmt(field, dbObjReprs)

  result.add columns.join(",\n")
  result.add "\n)"

proc genTableSchemas*(dbObjReprs: openarray[ObjRepr]): seq[string] =
  ## Generate table schemas for a list of object representations.

  for dbObjRepr in dbObjReprs:
    result.add genTableSchema(dbObjRepr, dbObjReprs)

proc genDropTableQueries*(dbObjReprs: seq[ObjRepr]): seq[string] =
  ## Generate ``DROP TABLE`` queries for a list of object representations.

  for dbObjRepr in dbObjReprs:
    result.add "DROP TABLE IF EXISTS $#" % dbObjRepr.getTable()

proc genInsertQuery*(obj: object, force: bool): SqlQuery =
  ## Generate ``INSERT`` query for an object.

  var fields: seq[string]

  for field, _ in obj.fieldPairs:
    if force or not obj[field].hasCustomPragma(ro):
      fields.add field

  result = sql "INSERT INTO ? ($#) VALUES ($#)" % [fields.join(", "),
                                                    '?'.repeat(fields.len).join(", ")]

proc genGetOneQuery*(obj: object): SqlQuery =
  ## Generate ``SELECT`` query to fetch a single record for an object.

  sql "SELECT $# FROM ? WHERE id = ?" % obj.fieldNames.join(", ")

proc genGetManyQuery*(obj: object): SqlQuery =
  ## Generate ``SELECT`` query to fetch multiple records for an object.

  sql "SELECT $# FROM ? LIMIT ? OFFSET ?" % obj.fieldNames.join(", ")

proc getUpdateQuery*(obj: object, force: bool): SqlQuery =
  ## Generate ``UPDATE`` query for an object.

  var fieldsWithPlaceholders: seq[string]

  for field, value in obj.fieldPairs:
    if force or not obj[field].hasCustomPragma(ro):
      fieldsWithPlaceholders.add field & " = ?"

  result = sql "UPDATE ? SET $# WHERE id = ?" % fieldsWithPlaceholders.join(", ")

proc genDeleteQuery*(obj: object): SqlQuery =
  ## Generate ``DELETE`` query for an object.

  sql "DELETE FROM ? WHERE id = ?"

proc getTable*(T: type): string =
  ##[ Get the name of the DB table for the given type: ``table`` pragma value if it exists
  or lowercased type name otherwise.
  ]##

  when T.hasCustomPragma(table): T.getCustomPragmaVal(table)
  else: T.name.toLowerAscii()

template genMakeDbTmpl(connection, user, password, database: string,
                        tableSchemas, dropTableQueries: openarray[string],
                        dbOthers: NimNode): untyped {.dirty.} =
  ## Generate ``withDb`` template.

  template withDb(body: untyped): untyped {.dirty.} =
    ##[ A wrapper for actions that require DB connection. Defines CRUD procs to work with the DB,
    as well as ``createTables`` and ``dropTables`` procs.

      Aforementioned procs and procs defined in a ``db`` block can be used only
      in  a ``withDb`` block.
    ]##

    block:
      let dbConn = open(connection, user, password, database)

      template dropTables() =
        ## Drop tables for all types in all type sections under ``db`` macro.

        for dropTableQuery in dropTableQueries:
          debug "Drop table", query = dropTableQuery
          dbConn.exec sql dropTableQuery

      template createTables(force = false) =
        ##[ Create tables for all types in all type sections under ``db`` macro.

        If ``force`` is ``true``, drop tables beforehand.
        ]##

        if force:
          dropTables()

        for tableSchema in tableSchemas:
          debug "Create table", query = tableSchema
          dbConn.exec sql tableSchema

      template insert(obj: var object, force = false) =
        ##[ Insert object instance as a record into DB.The object's id is updated after
        the insertion.

        By default, readonly fields are not inserted. Use ``force=true`` to insert all fields.
        ]##

        var values: seq[string]

        for _, value in obj.fieldPairs:
          when force or not obj[_].hasCustomPragma(ro):
            values.add $value

        obj.id = dbConn.insertID(genInsertQuery(obj, force), type(obj).getTable() & values).int

      template getOne(obj: var object, id: int) =
        ## Read a record from DB and store it into an existing object instance.

        let
          params = [type(obj).getTable(), $id]
          row = dbConn.getRow(genGetOneQuery(obj), params)

        if row.isEmpty():
          raise newException(KeyError, "Record with id=$# not found." % $id)

        row.to(obj)

      proc getOne(T: type, id: int): T =
        ## Read a record from DB into a new object instance.

        result.getOne(id)

      proc getMany(objs: var seq[object], limit: int,  offset = 0) =
        ## Read ``limit`` records from DB into an existing open array of objects with ``offset``.

        if len(objs) == 0: return

        let
          params = [type(objs[0]).getTable(), $min(limit, len(objs)), $offset]
          rows = dbConn.getAllRows(genGetManyQuery(objs[0]), params)

        rows.to(objs)

      proc getMany(T: type, limit: int, offset = 0): seq[T] =
        ##[ Read ``limit`` records from DB into a sequence of objects with ``offset``,
        create the sequence on the fly.
        ]##

        result.setLen limit
        result.getMany(limit, offset)

      template update(obj: object, force = false) =
        ##[ Update DB record with object field values.

        By default, readonly fields are not updated. Use ``force=true`` to update all fields.
        ]##

        var values: seq[string]

        for _, value in obj.fieldPairs:
          when force or not obj[_].hasCustomPragma(ro):
            values.add $value

        dbConn.exec(getUpdateQuery(obj, force), type(obj).getTable() & values & $obj.id)

      template delete(obj: var object) =
        ## Delete a record in DB by object's id. The id is set to 0 after the deletion.

        dbConn.exec(genDeleteQuery(obj), type(obj).getTable(), obj.id)
        obj.id = 0

      dbOthers

      try: body
      finally: dbConn.close()

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
            PragmaRepr(name: "ro", kind: pkFlag)
          ]
        ),
        typ: ident "int"
      )
      objRepr.fields.insert(idField, 0)

    result.add objRepr.toTypeDef()

macro db*(connection, user, password, database: string, body: untyped): untyped =
  ##[ DB models definition. Models are defined as regular Nim objects in regular ``type`` sections.

  ``connection``, ``user``, ``password``, ``database`` are the same args accepted
  by a standard ``dbConn`` instance.

  The macro generates ``withDb`` template that wraps all DB interations.
  ]##

  runnableExamples:
    import db_sqlite

    db(":memory:", "", "", ""):
      type
        User {.table: "users".} = object
          email: string
          age: int
        Book {.table: "books".} = object
          title: string
          author {.fk: User.}: string

      ## Define custom DB procs:
      proc getUsersByEmail(email: string): seq[User] =
        dbConn.getAllRows(sql "SELECT id, email, age FROM users WHERE email = ?", email).to User

    withDb:
      createTables()

      ## Instantiate an object and insert it as a record:
      var user = User(email: "hello@norm.nim", age: 30)
      user.insert()

      ## Retrieve the newly created record as an object:
      doAssert User.getOne(user.id).email == "hello@norm.nim"

      ## Use custom DB proc defined in ``db`` block:
      doAssert getUsersByEmail("hello@norm.nim") == @[user]

      dropTables()

  result = newStmtList()

  var
    dbTypeSections = newStmtList()
    dbObjReprs: seq[ObjRepr]
    dbOthers = newStmtList()

  for node in body:
    if node.kind == nnkTypeSection:
      dbTypeSections.add node.ensureIdFields()
    else:
      dbOthers.add node

  for typeSection in dbTypeSections:
    for typeDef in typeSection:
      dbObjReprs.add typeDef.toObjRepr()

  result.add getAst genMakeDbTmpl(connection, user, password, database,
                                  genTableSchemas(dbObjReprs), genDropTableQueries(dbObjReprs),
                                  dbOthers)
  result.add dbTypeSections
