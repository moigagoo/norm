import strutils, strformat, macros
import typetraits
import db_sqlite

import chronicles

import objutils, rowutils


template pk* {.pragma.}

template ro* {.pragma.}

template fk*(val: type) {.pragma.}

template dbType*(val: string) {.pragma.}

template table*(val: string) {.pragma.}

template db*(val: DbConn) {.pragma.}

proc getTable(objRepr: ObjRepr): string =
  result = objRepr.signature.name.toLowerAscii()

  for prag in objRepr.signature.pragmas:
    if prag.name == "table" and prag.kind == pkKval:
      return $prag.value

proc getDbType(fieldRepr: FieldRepr): string =
  result = case $fieldRepr.typ
  of "int": "INTEGER"
  of "string": "TEXT"
  of "float": "REAL"
  else: "TEXT"

  for prag in fieldRepr.signature.pragmas:
    if prag.name == "dbType" and prag.kind == pkKval:
      return $prag.value

proc getColumn(fieldRepr: FieldRepr): string =
  result.add fieldRepr.signature.name
  result.add " "
  result.add getDbType(fieldRepr)

  for prag in fieldRepr.signature.pragmas:
    if prag.name == "pk" and prag.kind == pkFlag:
      result.add " PRIMARY KEY"
    elif prag.name == "fk" and prag.kind == pkKval:
      result.add ", FOREIGN KEY ($#) REFERENCES {$#.getTable()}(id)" %
                      [fieldRepr.signature.name, $prag.value]

proc getTableSchema(typeDef: NimNode): string =
  ## Get table schema from a type definition.

  expectKind(typeDef, nnkTypeDef)

  let objRepr = typeDef.toObjRepr()

  result.add "CREATE TABLE $# (\n" % objRepr.getTable()

  var columns: seq[string]

  for field in objRepr.fields:
    columns.add "\t$#" % getColumn(field)

  result.add columns.join(",\n")
  result.add "\n);"

proc getDbSchema(typeSections: NimNode): string =
  ## Get DB schema from a list of type sections.

  expectKind(typeSections, nnkStmtList)

  var tableSchemas: seq[string]

  for typeSection in typeSections:
    for typeDef in typeSection:
      tableSchemas.add getTableSchema(typeDef)

  result = tableSchemas.join("\n")

proc getDropTableStmt(typeDef: NimNode): string =
  expectKind(typeDef, nnkTypeDef)
  "DROP TABLE IF EXISTS $#;" % typeDef.toObjRepr().getTable()

proc getDropTablesStmt(typeSections: NimNode): string =
  expectKind(typeSections, nnkStmtList)

  var dropTableStmts: seq[string]

  for typeSection in typeSections:
    for typeDef in typeSection:
      dropTableStmts.add getDropTableStmt(typeDef)

  result = dropTableStmts.join("\n")

proc getTable(T: type): string =
  ##[ Get the name of the DB table for the given type: ``table`` pragma value if it exists
  or lowercased type name otherwise.
  ]##

  when T.hasCustomPragma(table): T.getCustomPragmaVal(table)
  else: T.name.toLowerAscii()

template makeWithDb(connection, user, password, database, schema, dropTablesStmt: string,
                        dbOthers: NimNode): untyped {.dirty.} =
  template withDb*(body: untyped): untyped {.dirty.} =
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

macro db*(connection, user, password, database: string, body: untyped): untyped =
  result = newStmtList()

  var
    dbTypeSections = newStmtList()
    dbOthers = newStmtList()

  for node in body:
    if node.kind == nnkTypeSection:
      dbTypeSections.add node.ensureIdFields()
    else:
      dbOthers.add node

  result.add getAst makeWithDb(connection, user, password, database,
                                getDbSchema(dbTypeSections), getDropTablesStmt(dbTypeSections),
                                dbOthers)
  result.add dbTypeSections


db("rester.db", "", "", ""):
  type
    User {.table: "users".} = object
      email: string
      age: int
    Book {.table: "books".} = object
      title: string
      author {.fk: User.}: int
    Edition {.table: "editions".} = object
      title: string
      bookId {.fk: Book.}: int


when isMainModule:
  withDb:
    echo '-'.repeat(10)

    echo "Create tables."
    createTables(force=true)

    echo "Create ten users."
    for i in 1..10:
      var user = User(email: "foo-$#@bar.com" % $i, age: i*i)
      user.insert()

  withDb:
    echo '-'.repeat(10)

    echo "Insert user:"
    var user = User(email: "qwe@asd.zxc", age: 20)
    user.insert()
    echo User.getOne(user.id)

    echo "Delete user."
    user.delete()

  withDb:
    echo '-'.repeat(10)

    echo "Get first 100 users:"
    for user in User.getMany 100:
      echo user

    echo '-'.repeat(10)

    echo "Get user with id 1:"
    echo User.getOne(1)

    echo '-'.repeat(10)

    echo "Get user with id 1493:"
    try:
      echo User.getOne(1493)
    except KeyError:
      echo getCurrentExceptionMsg()

  withDb:
    echo '-'.repeat(10)

    echo "Update user with id 1:"
    var user = User.getOne(1)
    user.age.inc
    user.update()
    assert user == User.getOne(1)
    echo user