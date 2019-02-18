import strutils, strformat, macros
import typetraits
import db_sqlite

import chronicles

import norm / [objutils, rowutils]


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
  ## Add a ``CHECK <CONDITION>}`` constraint.

template table*(val: string) {.pragma.}
  ## Set table name.

proc getTable(objRepr: ObjRepr): string =
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

proc genColStmt(fieldRepr: FieldRepr): string =
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
        ", FOREIGN KEY ($#) REFERENCES {$#.getTable()}(id)" % [fieldRepr.signature.name,
                                                                $prag.value]
      of nnkDotExpr:
        ", FOREIGN KEY ($#) REFERENCES {$#.getTable()}($#)" % [fieldRepr.signature.name,
                                                                $prag.value[0], $prag.value[1]]
      else: ""

proc genTableSchema(typeDef: NimNode): string =
  ## Generate table schema for a type definition.

  expectKind(typeDef, nnkTypeDef)

  let objRepr = typeDef.toObjRepr()

  result.add "CREATE TABLE $# (\n" % objRepr.getTable()

  var columns: seq[string]

  for field in objRepr.fields:
    columns.add "\t$#" % genColStmt(field)

  result.add columns.join(",\n")
  result.add "\n);"

proc genDbSchema(typeSections: NimNode): string =
  ## Generate DB schema for a list of type sections.

  expectKind(typeSections, nnkStmtList)

  var tableSchemas: seq[string]

  for typeSection in typeSections:
    for typeDef in typeSection:
      tableSchemas.add genTableSchema(typeDef)

  result = tableSchemas.join("\n")

proc genDropTableStmt(typeDef: NimNode): string =
  ## Generate a ``DROP TABLE`` statement for a type definition.

  expectKind(typeDef, nnkTypeDef)
  "DROP TABLE IF EXISTS $#;" % typeDef.toObjRepr().getTable()

proc genDropTablesStmt(typeSections: NimNode): string =
  ## Generate ``DROP TABLE`` statements for a list of type sections.

  expectKind(typeSections, nnkStmtList)

  var dropTableStmts: seq[string]

  for typeSection in typeSections:
    for typeDef in typeSection:
      dropTableStmts.add genDropTableStmt(typeDef)

  result = dropTableStmts.join("\n")

proc getTable(T: type): string =
  ##[ Get the name of the DB table for the given type: ``table`` pragma value if it exists
  or lowercased type name otherwise.
  ]##

  when T.hasCustomPragma(table): T.getCustomPragmaVal(table)
  else: T.name.toLowerAscii()

template genMakeDbTmpl(connection, user, password, database, schema, dropTablesStmt: string,
                        dbOthers: NimNode): untyped {.dirty.} =
  ## Generate ``withDb`` template.

  template withDb*(body: untyped): untyped {.dirty.} =
    ##[ A wrapper for actions that require DB connection. Defines CRUD procs to work with the DB,
    as well as ``createTables`` and ``dropTables`` procs.

      Aforementioned procs and procs defined in a ``db`` block can be used only
      in  a ``withDb`` block.
    ]##

    block:
      let dbConn = open(connection, user, password, database)

      template dropTables() =
        ## Drop tables for all types in all type sections under ``db`` macro.

        debug "Drop tables", query = dropTablesStmt

        dbConn.exec sql dropTablesStmt

      template createTables(force = false) =
        ##[ Create tables for all types in all type sections under ``db`` macro.

        If ``force`` is ``true``, drop tables beforehand.
        ]##

        if force:
          dropTables()

        debug "Create tables", query = &schema

        dbConn.exec sql &schema

      template insert(obj: var object, force = false) =
        ##[ Insert object instance as a record into DB.The object's id is updated after
        the insertion.

        By default, readonly fields are not inserted. Use ``force=true`` to insert all fields.
        ]##

        var fields, values: seq[string]

        for field, value in obj.fieldPairs:
          when force or not obj[field].hasCustomPragma(ro):
            fields.add field
            values.add $value

        let
          placeholders = '?'.repeat(fields.len).join(", ")
          query = sql "INSERT INTO ? ($#) VALUES ($#)" % [fields.join(", "), placeholders]
          params = type(obj).getTable() & values

        obj.id = dbConn.insertID(query, params).int

      template update(obj: object, force = false) =
        ##[ Update DB record with object field values.

        By default, readonly fields are not updated. Use ``force=true`` to update all fields.
        ]##

        var fieldsWithPlaceholders, values: seq[string]

        for field, value in obj.fieldPairs:
          when force or not obj[field].hasCustomPragma(ro):
            fieldsWithPlaceholders.add field & " = ?"
            values.add $value

        let
          query = sql "UPDATE ? SET $# WHERE id = ?" % fieldsWithPlaceholders.join(", ")
          params = type(obj).getTable() & values & $obj.id

        dbConn.exec(query, params)

      template getOne(obj: var object, id: int) =
        ## Read a record from DB and store it into an existing object instance.

        let
          query = sql "SELECT $# FROM ? WHERE id = ?" % obj.fieldNames.join(", ")
          params = [type(obj).getTable(), $id]

        let row = dbConn.getRow(query, params)

        if row.isEmpty():
          raise newException(KeyError, "Record with id=$# doesn't exist." % $id)

        row.to(obj)

      proc getOne(T: type, id: int): T = result.getOne(id)
        ## Read a record from DB into a new object instance.

      proc getMany(objs: var seq[object], limit: int,  offset = 0) =
        ## Read ``limit`` records from DB into an existing open array of objects with ``offset``.

        if len(objs) == 0: return

        let
          query = sql "SELECT $# FROM ? LIMIT ? OFFSET ?" % objs[0].fieldNames.join(", ")
          params = [type(objs[0]).getTable(), $min(limit, len(objs)), $offset]
          rows = dbConn.getAllRows(query, params)

        rows.to(objs)

      proc getMany(T: type, limit: int, offset = 0): seq[T] =
        ##[ Read ``limit`` records from DB into a sequence of objects with ``offset``,
        create the sequence on the fly.
        ]##

        result.setLen limit
        result.getMany(limit, offset)

      template delete(obj: var object) =
        ## Delete a record in DB by object's id. The id is set to 0 after the deletion.

        dbConn.exec(sql"DELETE FROM ? WHERE id = ?", type(obj).getTable(), obj.id)
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

macro db*(backend: untyped, connection, user, password, database: string, body: untyped): untyped =
  ##[ DB models definition. Models are defined as regular Nim objects in a regular ``type`` section.

  ``backend`` is one of ``db_sqlite`` or ``db_postgres``.

  ``connection``, ``user``, ``password``, ``database`` are the same args accepted
  by a standard ``dbConn`` instance.

  The macro generates ``withDb`` template that can be used to query the DB.

  Additional pragmas are used to finetune DB and tables.
  ]##

  result = newStmtList()

  var
    dbTypeSections = newStmtList()
    dbOthers = newStmtList()

  for node in body:
    if node.kind == nnkTypeSection:
      dbTypeSections.add node.ensureIdFields()
    else:
      dbOthers.add node

  result.add getAst genMakeDbTmpl(connection, user, password, database,
                                  genDbSchema(dbTypeSections), genDropTablesStmt(dbTypeSections),
                                  dbOthers)
  result.add dbTypeSections


db(db_sqlite, ":memory:", "", "", ""):
  type
    User {.table: "users".} = object
      email: string
      age: int
    Book {.table: "books".} = object
      title: string
      author {.fk: User.id.}: int
    Edition {.table: "editions".} = object
      title: string
      bookId {.fk: Book.}: int


when isMainModule:
  withDb:
    block:
      info "Create tables"
      createTables(force=true)

      info "Populate tables"
      for i in 1..10:
        var user = User(email: "foo-$#@bar.com" % $i, age: i*i)
        user.insert()

    block:
      var user = User(email: "qwe@asd.zxc", age: 20)
      info "Add user", user = user
      user.insert()
      info "Get new user from db", user = User.getOne(user.id)
      info "Delete user"
      user.delete()

    block:
      info "Get the first 100 users", users = User.getMany 100
      info "Get the user with id = 1", user = User.getOne(1)
      try:
        info "Get the user with id = 1493", user = User.getOne(1493)
      except KeyError:
        warn getCurrentExceptionMsg()

    block:
      var user = User.getOne(1)
      info "Update user with id 1", user = user
      user.age.inc
      user.update()
      info "Updated user", user = user
      info "Get updated user from db", user = User.getOne(1)
