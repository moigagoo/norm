import strutils, macros, typetraits
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
  else: T.name.toLower()

template makeWithDbConn(connection, user, password, database: string,
                        dbProcs: NimNode): untyped {.dirty.} =
  template withDbConn*(body: untyped): untyped {.dirty.} =
    block:
      let dbConn = open(connection, user, password, database)

      proc getAll(T: type): seq[T] =
        for row in dbConn.fastRows(sql"SELECT * FROM ?", T.getTable()):
          result.add row.to(T)

      proc getById(T: type, id: int): T =
        dbConn.getRow(sql"SELECT  * FROM ? WHERE id = ?", T.getTable(), id).to(T)

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

  result.add getAst(makeWithDbConn(connection, user, password, database, dbProcs))
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
    UserBook = object
      userId: int
      bookId: int
    Edition {.table: "editions".} = object
      id {.pk.}: int
      title: string
      bookId: int

  proc books(user: User): seq[Book] =
    let query = sql"""
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
    echo User.getAll()
    echo Book.getAll()
    echo Edition.getAll()
    echo UserBook.getAll()
    echo User.getById(1)
    echo User.getById(1).books
    echo Book.getById(1).authors
