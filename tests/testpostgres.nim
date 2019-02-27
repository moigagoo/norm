import unittest

import os, strutils, sequtils

import norm / postgres


db("db", "postgres", "", "postgres"):
  type
    User {.table: "users".} = object
      email: string
      age: int
    Book {.table: "books".} = object
      title: string
      authorEmail {.fk: User.email.}: string
    Edition {.table: "editions".} = object
      title: string
      bookId {.fk: Book.}: int

suite "Creating and dropping tables, CRUD":
  setup:
    withDb:
      createTables(force=true)

      for i in 1..10:
        var
          user = User(email: "test-$#@example.com" % $i, age: i*i)
          book = Book(title: "Book $#" % $i, authorEmail: user.email)
          edition = Edition(title: "Edition $#" % $i)

        user.insert()
        book.insert()

        edition.bookId = book.id
        edition.insert()

  teardown:
    withDb:
      dropTables()

  test "Create tables":
    withDb:
      check dbConn.tryExec sql "SELECT id, email, age FROM users"
      check dbConn.tryExec sql "SELECT title, authorEmail FROM books"
      check dbConn.tryExec sql "SELECT title, bookId FROM editions"

  test "Create records":
    withDb:
      let
        users = User.getMany 100
        books = Book.getMany 100
        editions = Edition.getMany 100

      check len(users) == 10
      check len(books) == 10
      check len(editions) == 10

      check users[3].id == 4
      check users[3].email == "test-4@example.com"
      check users[3].age == 16

      check books[5].id == 6
      check books[5].title == "Book 6"
      check books[5].authorEmail == users[5].email

      check editions[7].id == 8
      check editions[7].title == "Edition 8"
      check editions[7].bookId == books[7].id

  test "Read records":
    withDb:
      var
        users = User().repeat 10
        books = Book().repeat 10
        editions = Edition().repeat 10

      users.getMany(20, offset=5)
      books.getMany(20, offset=5)
      editions.getMany(20, offset=5)

      check len(users) == 5
      check users[0].id == 6
      check users[^1].id == 10

      check len(books) == 5
      check books[0].id == 6
      check books[^1].id == 10

      check len(editions) == 5
      check editions[0].id == 6
      check editions[^1].id == 10

      var
        user = User()
        book = Book()
        edition = Edition()

      user.getOne 8
      book.getOne 8
      edition.getOne 8

      check user.id == 8
      check book.id == 8
      check edition.id == 8

  test "Update records":
    withDb:
      var
        user = User.getOne 2
        book = Book.getOne 2
        edition = Edition.getOne 2

      user.email = "new@example.com"
      book.title = "New Book"
      edition.title = "New Edition"

      user.update()
      book.update()
      edition.update()

    withDb:
      check User.getOne(2).email == "new@example.com"
      check Book.getOne(2).title == "New Book"
      check Edition.getOne(2).title == "New Edition"

  test "Delete records":
    withDb:
      var
        user = User.getOne 2
        book = Book.getOne 2
        edition = Edition.getOne 2

      user.delete()
      book.delete()
      edition.delete()

      expect KeyError:
        discard User.getOne 2

      expect KeyError:
        discard Book.getOne 2

      expect KeyError:
        discard Edition.getOne 2

  test "Drop tables":
    withDb:
      dropTables()

      expect DbError:
        dbConn.exec sql "SELECT NULL FROM users"
        dbConn.exec sql "SELECT NULL FROM books"
        dbConn.exec sql "SELECT NULL FROM editions"

  removeFile "test.db"
