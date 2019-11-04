import unittest

import os, strutils, sequtils, times

import norm/sqlite


const
  dbName = "test.db"
  customDbName = "custom_test.db"


db(dbName, "", "", ""):
  type
    User {.table: "users".} = object
      email {.unique.}: string
      ssn: Option[int]
      birthDate {.
        dbType: "INTEGER",
        notNull,
        parseIt: it.i.fromUnix().local(),
        formatIt: ?it.toTime().toUnix()
      .}: DateTime
      lastLogin: DateTime
    Publisher {.table: "publishers".} = object
      title {.unique.}: string
      licensed: bool
    Book {.table: "books".} = object
      title: string
      authorEmail {.fk: User.email, onDelete: "CASCADE".}: string
      publisherTitle {.fk: Publisher.title.}: string

  proc getBookById(id: DbValue): Book = withDb(Book.getOne int(id.i))

  type
    Edition {.table: "editions".} = object
      title: string
      book {.
        dbCol: "bookId",
        dbType: "INTEGER",
        notNull,
        fk: Book
        parser: getBookById,
        formatIt: ?it.id,
        onDelete: "CASCADE"
      .}: Book


suite "Creating and dropping tables, CRUD":
  setup:
    withDb:
      transaction:
        createTables(force=true)

        for i in 1..9:
          var
            user = User(
              email: "test-$#@example.com" % $i,
              ssn: some i,
              birthDate: parse("200$1-0$1-0$1" % $i, "yyyy-MM-dd"),
              lastLogin: parse("2019-08-19 23:32:5$1+04" % $i, "yyyy-MM-dd HH:mm:sszz")
            )
            publisher = Publisher(title: "Publisher $#" % $i, licensed: if i < 6: true else: false)
            book = Book(title: "Book $#" % $i, authorEmail: user.email,
                        publisherTitle: publisher.title)
            edition = Edition(title: "Edition $#" % $i)

          user.insert()
          publisher.insert()
          book.insert()

          edition.book = book
          edition.insert()

  teardown:
    withDb:
      dropTables()

  test "Create tables":
    withDb:
      let query = "PRAGMA table_info($#);"

      check dbConn.getAllRows(sql query % "users") == @[
        @[?0, ?"id", ?"INTEGER", ?1, ?"0", ?1],
        @[?1, ?"email", ?"TEXT", ?1, ?"''", ?0],
        @[?2, ?"ssn", ?"INTEGER", ?0, ?nil, ?0],
        @[?3, ?"birthDate", ?"INTEGER", ?1, ?nil, ?0],
        @[?4, ?"lastLogin", ?"INTEGER", ?1, ?"0", ?0]
      ]
      check dbConn.getAllRows(sql query % "books") == @[
        @[?0, ?"id", ?"INTEGER", ?1, ?"0", ?1],
        @[?1, ?"title", ?"TEXT", ?1, ?"''", ?0],
        @[?2, ?"authorEmail", ?"TEXT", ?1, ?"''", ?0],
        @[?3, ?"publisherTitle", ?"TEXT", ?1, ?"''", ?0],
      ]
      check dbConn.getAllRows(sql query % "editions") == @[
        @[?0, ?"id", ?"INTEGER", ?1, ?"0", ?1],
        @[?1, ?"title", ?"TEXT", ?1, ?"''", ?0],
        @[?2, ?"bookId", ?"INTEGER", ?1, ?nil, ?0]
      ]

  test "Create records":
    withDb:
      let
        publishers = Publisher.getMany 100
        books = Book.getMany 100
        editions = Edition.getMany 100

      check len(publishers) == 9
      check len(books) == 9
      check len(editions) == 9

      check publishers[3].id == 4
      check publishers[3].title == "Publisher 4"

      check books[5].id == 6
      check books[5].title == "Book 6"

      check editions[7].id == 8
      check editions[7].title == "Edition 8"
      check editions[7].book == books[7]

    withDb:
      let
        publishers = Publisher.getAll()
        books = Book.getAll()
        editions = Edition.getAll()

      check len(publishers) == 9
      check len(books) == 9
      check len(editions) == 9

      check publishers[1].id == 2
      check publishers[1].title == "Publisher 2"

      check books[3].id == 4
      check books[3].title == "Book 4"

      check editions[8].id == 9
      check editions[8].title == "Edition 9"
      check editions[8].book == books[8]

  test "Read records":
    withDb:
      var
        users = @[
          User(birthDate: now(), lastLogin: now()),
          User(birthDate: now(), lastLogin: now()),
          User(birthDate: now(), lastLogin: now()),
          User(birthDate: now(), lastLogin: now()),
          User(birthDate: now(), lastLogin: now()),
          User(birthDate: now(), lastLogin: now()),
          User(birthDate: now(), lastLogin: now()),
          User(birthDate: now(), lastLogin: now()),
          User(birthDate: now(), lastLogin: now()),
          User(birthDate: now(), lastLogin: now())
        ]
        publishers = Publisher().repeat 10
        books = Book().repeat 10
        editions = Edition().repeat 10

      users.getMany(20, offset=5)
      publishers.getMany(20, offset=5)
      books.getMany(20, offset=5)
      editions.getMany(20, offset=5)

      check len(users) == 4
      check users[0].id == 6
      check users[^1].id == 9

      check len(publishers) == 4
      check publishers[0].id == 6
      check publishers[^1].id == 9

      check len(books) == 4
      check books[0].id == 6
      check books[^1].id == 9

      check len(editions) == 4
      check editions[0].id == 6
      check editions[^1].id == 9

      users.getAll()
      publishers.getAll()
      books.getAll()
      editions.getAll()

      check len(users) == 9
      check users[0].id == 1
      check users[^1].id == 9

      check len(publishers) == 9
      check publishers[0].id == 1
      check publishers[^1].id == 9

      check len(books) == 9
      check books[0].id == 1
      check books[^1].id == 9

      check len(editions) == 9
      check editions[0].id == 1
      check editions[^1].id == 9

      var
        user = User(birthDate: now(), lastLogin: now())
        publisher = Publisher()
        book = Book()
        edition = Edition()

      user.getOne 8
      publisher.getOne 8
      book.getOne 8
      edition.getOne 8

      check user.id == 8
      check publisher.id == 8
      check book.id == 8
      check edition.id == 8

  test "Query records":
    withDb:
      let someBooks = Book.getMany(10, cond="title IN (?, ?) ORDER BY title DESC",
                                   params=[?"Book 1", ?"Book 5"])

      check len(someBooks) == 2
      check someBooks[0].title == "Book 5"
      check someBooks[1].authorEmail == "test-1@example.com"

      let someBook = Book.getOne("authorEmail=?", "test-2@example.com")
      check someBook.id == 2

      expect KeyError:
        let notExistingBook {.used.} = Book.getOne("title=?", "Does not exist")

    withDb:
      let someBooks = Book.getAll(cond="title NOT IN (?, ?, ?) ORDER BY title DESC",
                                  params=[?"Book 1", ?"Book 5", ?"Book 9"])

      check len(someBooks) == 6

      check someBooks[0].title == "Book 8"
      check someBooks[1].authorEmail == "test-7@example.com"

      check someBooks[5].title == "Book 2"
      check someBooks[4].authorEmail == "test-3@example.com"

  test "Update records":
    withDb:
      var
        book = Book.getOne 2
        edition = Edition.getOne 2

      book.title = "New Book"
      edition.title = "New Edition"

      book.update()
      edition.update()

    withDb:
      check Book.getOne(2).title == "New Book"
      check Edition.getOne(2).title == "New Edition"

  test "Delete records":
    withDb:
      var
        book = Book.getOne 2
        edition = Edition.getOne 2

      book.delete()
      edition.delete()

      expect KeyError:
        discard Book.getOne 2

      expect KeyError:
        discard Edition.getOne 2

  test "Drop tables":
    withDb:
      User.dropTable()

      expect DbError:
        dbConn.exec sql "SELECT NULL FROM users"

    withDb:
      dropTables()

      expect DbError:
        dbConn.exec sql "SELECT NULL FROM publishers"
        dbConn.exec sql "SELECT NULL FROM books"
        dbConn.exec sql "SELECT NULL FROM editions"

  test "Custom DB":
    withCustomDb(customDbName, "", "", ""):
      createTables(force=true)

    withCustomDb(customDbName, "", "", ""):
      let query = "PRAGMA table_info($#);"

      check dbConn.getAllRows(sql query % "users") == @[
        @[?0, ?"id", ?"INTEGER", ?1, ?"0", ?1],
        @[?1, ?"email", ?"TEXT", ?1, ?"''", ?0],
        @[?2, ?"ssn", ?"INTEGER", ?0, ?nil, ?0],
        @[?3, ?"birthDate", ?"INTEGER", ?1, ?nil, ?0],
        @[?4, ?"lastLogin", ?"INTEGER", ?1, ?"0", ?0]
      ]
      check dbConn.getAllRows(sql query % "books") == @[
        @[?0, ?"id", ?"INTEGER", ?1, ?"0", ?1],
        @[?1, ?"title", ?"TEXT", ?1, ?"''", ?0],
        @[?2, ?"authorEmail", ?"TEXT", ?1, ?"''", ?0],
        @[?3, ?"publisherTitle", ?"TEXT", ?1, ?"''", ?0],
      ]
      check dbConn.getAllRows(sql query % "editions") == @[
        @[?0, ?"id", ?"INTEGER", ?1, ?"0", ?1],
        @[?1, ?"title", ?"TEXT", ?1, ?"''", ?0],
        @[?2, ?"bookId", ?"INTEGER", ?1, ?nil, ?0]
      ]

    withCustomDb(customDbName, "", "", ""):
      dropTables()

      expect DbError:
        dbConn.exec sql "SELECT NULL FROM users"
        dbConn.exec sql "SELECT NULL FROM publishers"
        dbConn.exec sql "SELECT NULL FROM books"
        dbConn.exec sql "SELECT NULL FROM editions"

    removeFile customDbName

  removeFile dbName
