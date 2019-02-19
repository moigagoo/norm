import unittest

import os, strutils, sequtils, db_sqlite

import chronicles

import norm


const testDbFile = "test.db"


db(db_sqlite, testDbFile, "", "", ""):
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

  test "Table creation":
    withDb:
      check dbConn.tryExec sql "SELECT id, email, age FROM users"
      check dbConn.tryExec sql "SELECT title, authorEmail FROM books"
      check dbConn.tryExec sql "SELECT title, bookId FROM editions"

  test "Inserting records":
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

  test "Reading records":
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

  test "Deleting records":
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

  removeFile "test.db"


#   block:
#     var user = User.getOne(1)
#     info "Update user with id 1", user = user
#     user.age.inc
#     user.update()
#     info "Updated user", user = user
#     info "Get updated user from db", user = User.getOne(1)

#   block:
#     info "Drop tables"
#     dropTables()
#     try:
#       info "Get the first 10 users", users = User.getMany 10
#     except DbError:
#       warn getCurrentExceptionMsg()
