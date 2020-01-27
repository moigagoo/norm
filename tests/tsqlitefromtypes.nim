import unittest

import os, strutils, times

import norm/sqlite

import models/[user, pet]


const
  dbName = "test.db"
  customDbName = "custom_test.db"


dbFromTypes(dbName, "", "", "", [User, Pet])


suite "Creating and dropping tables, CRUD":
  setup:
    withDb:
      createTables(force=true)

      var user = User(email: "test@example.com", lastLogin: now())
      user.insert()

      var pet = Pet(name: "Spot", age: 3, ownerId: user.id)
      pet.insert()

  teardown:
    withDb:
      dropTables()

  test "Create tables":
    withDb:
      let query = "PRAGMA table_info($#);"

      check dbConn.getAllRows(sql query % "users") == @[
        @[?0, ?"id", ?"INTEGER", ?1, ?"0", ?1],
        @[?1, ?"email", ?"TEXT", ?1, ?"''", ?0],
        @[?2, ?"lastLogin", ?"INTEGER", ?1, ?"0", ?0]
      ]

      check dbConn.getAllRows(sql query % "pet") == @[
        @[?0, ?"id", ?"INTEGER", ?1, ?"0", ?1],
        @[?1, ?"name", ?"TEXT", ?1, ?"''", ?0],
        @[?2, ?"age", ?"INTEGER", ?1, ?"0", ?0],
        @[?3, ?"ownerId", ?"INTEGER", ?1, ?"0", ?0]
      ]

  test "Read records":
    withDb:
      var user = User(lastLogin: now()); user.getOne(1)
      let pet = Pet.getOne(1)

      check user.email == "test@example.com"
      check pet.name == "Spot"

  test "Update records":
    withDb:
      var user = User(lastLogin: now()); user.getOne(1)
      var pet = Pet.getOne(1)

      user.email = "foo@bar.baz"
      pet.name = "Fido"

      user.update()
      pet.update()

    withDb:
      var user = User(lastLogin: now()); user.getOne(1)

      check user.email == "foo@bar.baz"
      check Pet.getOne(1).name == "Fido"

  test "Delete records":
    withDb:
      var user = User(lastLogin: now()); user.getOne 1
      var pet =Pet.getOne 1

      user.delete()
      pet.delete()

      expect KeyError:
        var user = User(lastLogin: now())
        user.getOne 1

      expect KeyError:
        discard Pet.getOne 1

  test "Drop tables":
    withDb:
      dropTables()

      expect DbError:
        dbConn.exec sql "SELECT NULL FROM user"
        dbConn.exec sql "SELECT NULL FROM pet"

  test "Custom DB":
    withCustomDb(customDbName, "", "", ""):
      createTables(force=true)

    withCustomDb(customDbName, "", "", ""):
      let query = "PRAGMA table_info($#);"

      check dbConn.getAllRows(sql query % "users") == @[
        @[?0, ?"id", ?"INTEGER", ?1, ?"0", ?1],
        @[?1, ?"email", ?"TEXT", ?1, ?"''", ?0],
        @[?2, ?"lastLogin", ?"INTEGER", ?1, ?"0", ?0]
      ]

      check dbConn.getAllRows(sql query % "pet") == @[
        @[?0, ?"id", ?"INTEGER", ?1, ?"0", ?1],
        @[?1, ?"name", ?"TEXT", ?1, ?"''", ?0],
        @[?2, ?"age", ?"INTEGER", ?1, ?"0", ?0],
        @[?3, ?"ownerId", ?"INTEGER", ?1, ?"0", ?0]
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
