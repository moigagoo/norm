import unittest

import os, db_sqlite

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

  teardown:
    withDb:
      dropTables()

  test "Check table creation":
    withDb:
      check dbConn.tryExec(sql "SELECT NULL FROM users")

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
