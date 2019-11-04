import unittest

import strutils, sequtils, times

import norm/postgres


const
  dbHost = "postgres_1"
  customDbHost = "postgres_2"
  dbUser = "postgres"
  dbPassword = ""
  dbDatabase = "postgres"

db(dbHost, dbUser, dbPassword, dbDatabase):
  type
    User {.table: "users".} = object
      email {.unique.}: string
      birthDate {.
        dbType: "TEXT",
        parseIt: it.s.parse("yyyy-MM-dd", utc()),
        formatIt: ?it.format("yyyy-MM-dd")
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
        dbCol: "bookid",
        dbType: "INTEGER",
        fk: Book
        parser: getBookById,
        formatIt: ?it.id,
        onDelete: "CASCADE"
      .}: Book

suite "Creating and dropping tables, CRUD":
  setup:
    withDb:
      createTables(force=true)

      transaction:
        for i in 1..9:
          var
            user = User(
              email: "test-$#@example.com" % $i,
              birthDate: parse("200$1-0$1-0$1" % $i, "yyyy-MM-dd"),
              lastLogin: parse("2019-08-19 23:32:5$#+04" % $i, "yyyy-MM-dd HH:mm:sszz")
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
    proc getCols(table: string): seq[string] =
      let query = sql "SELECT column_name FROM information_schema.columns WHERE table_name = $1"

      withDb:
        for col in dbConn.getAllRows(query, table):
          result.add $col[0]

    check getCols("users") == @["id", "email", "birthdate", "lastlogin"]
    check getCols("publishers") == @["id", "title", "licensed"]
    check getCols("books") == @["id", "title", "authoremail", "publishertitle"]
    check getCols("editions") == @["id", "title", "bookid"]

  test "Create records":
    withDb:
      let
        books = Book.getMany 100
        editions = Edition.getMany 100

      check len(books) == 9
      check len(editions) == 9

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
      let someBooks = Book.getMany(10, cond="title IN ($1, $2) ORDER BY title DESC",
                                   params=[?"Book 1", ?"Book 5"])

      check len(someBooks) == 2
      check someBooks[0].title == "Book 5"
      check someBooks[1].authorEmail == "test-1@example.com"

      let someBook = Book.getOne("authoremail = $1", "test-2@example.com")
      check someBook.id == 2

      expect KeyError:
        let notExistingBook {.used.} = Book.getOne("title = $1", "Does not exist")

    withDb:
      let someBooks = Book.getAll(cond="title NOT IN ($1, $2, $3) ORDER BY title DESC",
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
      dropTables()

      expect DbError:
        dbConn.exec sql "SELECT NULL FROM users"
        dbConn.exec sql "SELECT NULL FROM publishers"
        dbConn.exec sql "SELECT NULL FROM books"
        dbConn.exec sql "SELECT NULL FROM editions"

  test "Custom DB":
    withCustomDb(customDbHost, "postgres", "", "postgres"):
      createTables(force=true)

    proc getCols(table: string): seq[string] =
      let query = sql "SELECT column_name FROM information_schema.columns WHERE table_name = $1"

      withCustomDb(customDbHost, "postgres", "", "postgres"):
        for col in dbConn.getAllRows(query, table):
          result.add $col[0]

    check getCols("users") == @["id", "email", "birthdate", "lastlogin"]
    check getCols("publishers") == @["id", "title", "licensed"]
    check getCols("books") == @["id", "title", "authoremail", "publishertitle"]
    check getCols("editions") == @["id", "title", "bookid"]

    withCustomDb(customDbHost, "postgres", "", "postgres"):
      dropTables()

      expect DbError:
        dbConn.exec sql "SELECT NULL FROM users"
        dbConn.exec sql "SELECT NULL FROM publishers"
        dbConn.exec sql "SELECT NULL FROM books"
        dbConn.exec sql "SELECT NULL FROM editions"
