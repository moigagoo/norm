import unittest

import os, strutils, db_sqlite

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

suite "Setting up and cleaning up DB":
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

  removeFile "test.db"

# when isMainModule:
# withDb:
#   block:
#     info "Create tables"
#     createTables(force=true)

#     info "Populate tables"
#     for i in 1..10:
#       var user = User(email: "foo-$#@bar.com" % $i, age: i*i)
#       user.insert()

#   block:
#     var user = User(email: "qwe@asd.zxc", age: 20)
#     info "Add user", user = user
#     user.insert()
#     info "Get new user from db", user = User.getOne(user.id)
#     info "Delete user"
#     user.delete()

#   block:
#     info "Get the first 100 users", users = User.getMany 100
#     info "Get the user with id = 1", user = User.getOne(1)
#     try:
#       info "Get the user with id = 1493", user = User.getOne(1493)
#     except KeyError:
#       warn getCurrentExceptionMsg()

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
