import strutils, macros, typetraits
import db_sqlite

import rowutils
export rowutils


template primaryKey() {.pragma.}

template tableName(val: string) {.pragma.}

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

macro models(body: untyped): untyped =
  result = newStmtList()
  result.add body

proc getAll*(T: type, dbConn: DbConn, tableName: string): seq[T] =
  for row in dbConn.fastRows(sql"SELECT * FROM ?", tableName):
    result.add row.to(T)

proc getAll*(T: type, dbConn: DbConn): seq[T] =
  let tableName =
    when T.hasCustomPragma(tableName): T.getCustomPragmaVal(tableName)
    else: T.name.toLower()

  for row in dbConn.fastRows(sql"SELECT * FROM ?", tableName):
    result.add row.to(T)

proc getById*(T: type, dbConn: DbConn, tableName: string, id: int): T =
  dbConn.getRow(sql"SELECT  * FROM ? WHERE id = ?", tableName, $id).to(T)

proc getById*(T: type, dbConn: DbConn, id: int): T =
  let tableName =
    when T.hasCustomPragma(tableName): T.getCustomPragmaVal(tableName)
    else: T.name.toLower()

  dbConn.getRow(sql"SELECT  * FROM ? WHERE id = ?", tableName, $id).to(T)


models:
  type
    User {.tableName: "users".} = object
      id {.primaryKey.}: int
      email: string
      age: int
    Book {.tableName: "books".} = object
      id {.primaryKey.}: int
      title: string

  # proc getUserId(user: User): string = $user.id

  proc getUserById(userId: string): User =
    let dbConn = open("rester.db", "", "", "")
    User.getById(dbConn, parseInt(userId))

  proc getBookId(book: Book): string = $book.id

  proc getBookById(bookId: string): Book =
    let dbConn = open("rester.db", "", "", "")
    Book.getById(dbConn, parseInt(bookId))

  type
    Edition {.tableName: "editions".} = object
      id {.primaryKey.}: int
      title: string
      book {.formatter: getBookId, parser: getBookById.}: Book
    UserBook = object
      user {.parser: getUserById.}: User
      book {.parser: getBookById.}: Book

when isMainModule:
  let dbConn = open("rester.db", "", "", "")

  echo User.getAll(dbConn)

  echo Book.getAll(dbConn)

  echo Edition.getAll(dbConn)

  echo UserBook.getAll(dbConn)

  dbConn.close()
