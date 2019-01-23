import strutils, strformat, macros, sequtils, options
import db_sqlite

import rowutils
export rowutils


template pk {.pragma.}

template table(val: string) {.pragma.}

template db(val: DbConn) {.pragma.}


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
                        dbProcs: NimNode): untyped {.dirty.} =
  template withDbConn*(body: untyped): untyped {.dirty.} =
    block:
      let dbConn = open(connection, user, password, database)

      proc all(T: type): seq[T] =
        for row in dbConn.fastRows(sql"SELECT * FROM ?", T.getTable()):
          result.add row.to(T)

      proc one(T: type, id: int): T =
        dbConn.getRow(sql"SELECT  * FROM ? WHERE id = ?", T.getTable(), id).to(T)

      proc where(T: type, clause: string): seq[T] =
        for row in dbConn.fastRows(sql &"SELECT * FROM ? WHERE {clause}", T.getTable()):
          result.add row.to(T)

      proc insert(obj: var object) =
        var fields: seq[string]

        for field, _ in obj.fieldPairs: fields.add field

        let query = sql "INSERT INTO $# ($#) VALUES ($#)" %
                    [type(obj).getTable(), fields.join(","), '?'.repeat(len(fields))]

        obj.id = dbConn.insertId(query, obj.toRow()).int

      proc delete(obj: var object) =
        dbConn.exec(
          sql"DELETE FROM ? WHERE id = ?",
          type(obj).getTable(), obj.id
        )
        obj.id = 0

      dbProcs

      try: body
      finally: dbConn.close()


macro db*(connection, user, password, database: string, body: untyped): untyped =
  result = newStmtList()

  var
    dbTypes = newStmtList()
    dbProcs = newStmtList()

  for node in body:
    expectKind(node, {nnkTypeSection, nnkProcDef})

    if node.kind == nnkProcDef:
      dbProcs.add node

    else:
      dbTypes.add node

  result.add getAst makeWithDbConn(connection, user, password, database, dbProcs)
  result.add dbTypes


db("rester.db", "", "", ""):
  type
    User {.table: "users".} = object
      id {.pk.}: int
      email: string
      age: int
    Book {.table: "books".} = object
      id {.pk.}: int
      title: string
    Edition {.table: "editions".} = object
      id {.pk.}: int
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
    for i in 1..10:
      var user = User(email: "asd@asd.asd", age: i)
      user.insert()

    echo User.all

  withDbConn:
    var users = User.all
    for user in users.filterIt(it.email=="asd@asd.asd").mitems:
      user.delete()

    echo User.all()
    # var usersAge1 = User.getWhere("age=1")
    # for user in usersAge1.mitems:
    #   user.delete()
    # echo User.getWhere("age=1")
