import strutils, strformat, macros
import typetraits
import db_sqlite

import objutils, rowutils


template pk* {.pragma.}
template autoinc* {.pragma.}

template protected* {.pragma.}

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
  when T.hasCustomPragma(table): T.getCustomPragmaVal(table)
  else: T.name.toLowerAscii()

template makeWithDbConn(connection, user, password, database: string,
                        dbOthers: NimNode): untyped {.dirty.} =
  template withDbConn*(body: untyped): untyped {.dirty.} =
    block:
      let dbConn = open(connection, user, password, database)

      template insert(obj: var object) =
        var fields, values: seq[string]

        for field, value in obj.fieldPairs:
          when not obj[field].hasCustomPragma(protected):
            fields.add field
            values.add $value

        let query = sql "INSERT INTO ? ($1) VALUES ($1)" % '?'.repeat(fields.len).join(",")

        obj.id = dbConn.insertID(query, obj.type.getTable() & fields & values).int

      dbOthers

      try: body
      finally: dbConn.close()

proc ensureIdField(typeSection: NimNode): NimNode =
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
        else: raise newException(ValueError,
                                  "Unexpected field definition type: " & $fieldNameDef.kind)

      fieldNames.add fieldName

    if "id" notin fieldNames:
      let idFieldDef = newIdentDefs(
        newNimNode(nnkPragmaExpr).add(
          ident "id",
          newNimNode(nnkPragma).add(
            ident "pk",
            ident "autoinc",
            ident "protected"
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

  proc setAge(user: var User, value: int) =
    dbConn.exec(sql"""UPDATE ? SET age = ? WHERE id = ?""", "users", value, user.id)
    user.age = value

  proc books(user: User): seq[Book] =
    const query = sql"""
        SELECT
          books.*
        FROM
          userbook JOIN books
          ON userbook.book_id = books.id
        WHERE
          userbook.user_id = ?
      """

    for row in dbConn.fastRows(query, user.id): result.add row.to(Book)

  proc authors(book: Book): seq[User] =
    let query = sql"""
        SELECT
          users.*
        FROM
          userbook JOIN users
          ON userbook.user_id = users.id
        WHERE
          userbook.book_id = ?
      """

    for row in dbConn.fastRows(query, book.id): result.add row.to(User)


when isMainModule:
  withDbConn:
    var u = User(email: "user@example.com", age: 23)

    u.insert()

    echo u

  #   echo User.all

  # withDbConn:
  #   var users = User.all
  #   for user in users.filterIt(it.email=="asd@asd.asd").mitems:
  #     user.delete()

  #   echo User.all()
  #   # var usersAge1 = User.getWhere("age=1")
  #   # for user in usersAge1.mitems:
  #   #   user.delete()
  #   # echo User.getWhere("age=1")
