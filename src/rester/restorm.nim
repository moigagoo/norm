import strutils, macros, typetraits
import db_sqlite

import rowutils
export rowutils


template pk() {.pragma.}

template table(val: string) {.pragma.}

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

macro tables(body: untyped): untyped =
  result = newStmtList()
  result.add body

proc getTable(T: type): string =
  when T.hasCustomPragma(table): T.getCustomPragmaVal(table)
  else: T.name.toLower()

proc getAll*(T: type, dbConn: DbConn): seq[T] =
  for row in dbConn.fastRows(sql"SELECT * FROM ?", T.getTable()):
    result.add row.to(T)

proc getById*(T: type, dbConn: DbConn, id: int): T =
  dbConn.getRow(sql"SELECT  * FROM ? WHERE id = ?", T.getTable(), $id).to(T)


tables:
  type
    User {.table: "users".} = object
      id {.pk.}: int
      email: string
      age: int
    Book {.table: "books".} = object
      id {.pk.}: int
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
    Edition {.table: "editions".} = object
      id {.pk.}: int
      title: string
      book {.toDb: getBookId, fromDb: getBookById.}: Book
    UserBook = object
      user {.fromDb: getUserById.}: User
      book {.fromDb: getBookById.}: Book

  proc books(user: User): seq[Book] =
    let
      dbConn = open("rester.db", "", "", "")
      query = sql"""
        SELECT books.*
        FROM userbook JOIN books ON userbook.book_id = books.id
        WHERE userbook.user_id = ?;"""

    for row in dbConn.fastRows(query, user.id):
      result.add row.to(Book)

  proc authors(book: Book): seq[User] =
    let
      dbConn = open("rester.db", "", "", "")
      query = sql"""
        SELECT users.*
        FROM userbook JOIN users ON userbook.user_id = users.id
        WHERE userbook.book_id = ?;"""

    for row in dbConn.fastRows(query, book.id):
      result.add row.to(User)

when isMainModule:
  let dbConn = open("rester.db", "", "", "")

  echo User.getAll(dbConn)

  echo Book.getAll(dbConn)

  echo Edition.getAll(dbConn)

  echo UserBook.getAll(dbConn)

  echo User.getById(dbConn, 1).books

  echo Book.getById(dbConn, 1).authors

  dbConn.close()