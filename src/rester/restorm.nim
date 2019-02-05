import strutils, macros
import typetraits
import db_sqlite

import objutils, rowutils


template pk* {.pragma.}

template ro* {.pragma.}

template dbType*(val: string) {.pragma.}

template table*(val: string) {.pragma.}

template db*(val: DbConn) {.pragma.}

template createTables*() =
  sql"""
    CREATE TABLE users (
      id INTEGER PRIMARY KEY,
      email TEXT,
      age INTEGER
    );

    CREATE TABLE books (
      id INTEGER PRIMARY KEY,
      title TEXT
    );

    CREATE TABLE editions (
      id INTEGER PRIMARY KEY,
      title TEXT,
      book_id INTEGER,
      FOREIGN KEY(book_id) REFERENCES books(id)
    );

    CREATE TABLE users_books (
      user_id INTEGER,
      book_id INTEGER,
      FOREIGN KEY(user_id) REFERENCES users(id),
      FOREIGN KEY(book_id) REFERENCES books(id)
    );
  """

proc getTable(T: type): string =
  ##[ Get the name of the DB table for the given type: ``table`` pragma value if it exists
  or lowercased type name otherwise.
  ]##

  when T.hasCustomPragma(table): T.getCustomPragmaVal(table)
  else: T.name.toLowerAscii()

template makeWithDbConn(connection, user, password, database: string,
                        dbOthers: NimNode): untyped {.dirty.} =
  template withDbConn*(body: untyped): untyped {.dirty.} =
    block:
      let dbConn = open(connection, user, password, database)

      template insert(obj: var object, force = false) =
        ##[ Insert object instance as a record into DB.The object's id is updated after
        the insertion.

        By default, readonly fields are not inserted. Use ``force=true`` to insert all fields.
        ]##

        var values: seq[string]

        for _, value in obj.fieldPairs:
          when force or not obj[field].hasCustomPragma(ro):
            values.add $value

        let
          placeholders = '?'.repeat(fields.len).join(", ")
          query = sql "INSERT INTO ? ($#) VALUES ($#)" % [obj.fieldNames.join(", "), placeholders]
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

proc ensureIdField(typeSection: NimNode): NimNode =
  ## Check if ``id`` field is in the object definition, insert it if it's not.

  result = newNimNode(nnkTypeSection)

  for typeDef in typeSection:
    let typeDefBody = typeDef[2]
    expectKind(typeDefBody, nnkObjectTy)

    var fieldNames: seq[string]

    var fieldDefs = typeDefBody[2]

    for fieldDef in fieldDefs:
      let fieldNameDef = fieldDef[0]
      expectKind(fieldNameDef, {nnkIdent, nnkPragmaExpr})

      let fieldName = case fieldNameDef.kind
        of nnkIdent: fieldNameDef.strVal
        of nnkPragmaExpr: fieldNameDef[0].strVal
        else: ""

      fieldNames.add fieldName

    if "id" notin fieldNames:
      let idFieldDef = newIdentDefs(
        newNimNode(nnkPragmaExpr).add(
          ident "id",
          newNimNode(nnkPragma).add(
            ident "pk",
            ident "ro"
          )
        ),
        ident "int",
        newEmptyNode()
      )

      fieldDefs.insert(0, idFieldDef)

    result.add typeDef


macro db*(connection, user, password, database: string, body: untyped): untyped =
  result = newStmtList()

  var
    dbTypes = newStmtList()
    dbOthers = newStmtList()

  for node in body:
    if node.kind == nnkTypeSection:
      dbTypes.add node.ensureIdField()
    else:
      dbOthers.add node

  result.add getAst makeWithDbConn(connection, user, password, database, dbOthers)
  result.add dbTypes


db("rester.db", "", "", ""):
  type
    User {.table: "users".} = object
      email: string
      age: int
    Book {.table: "books".} = object
      title: string
    Edition {.table: "editions".} = object
      title: string
      bookId: int
    UserBook = object
      userId: int
      bookId: int
