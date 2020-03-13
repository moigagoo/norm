import unittest

import strutils, times, algorithm

import norm/postgres

import models/[user, pet]


const
  dbHost = "postgres_1"
  customDbHost = "postgres_2"
  dbUser = "postgres"
  dbPassword = "postgres"
  dbDatabase = "postgres"

dbFromTypes(dbHost, dbUser, dbPassword, dbDatabase, [User, Pet])

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
    proc getCols(table: string): seq[string] =
      let query = sql "SELECT column_name FROM information_schema.columns WHERE table_name = $1 ORDER BY column_name"

      withDb:
        for col in dbConn.getAllRows(query, table):
          result.add $col[0]

    check getCols("users") == sorted @["id", "email", "lastlogin"]
    check getCols("pet") == sorted @["id", "name", "age", "ownerid"]

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
      var pet = Pet.getOne 1

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
        dbConn.exec sql "SELECT NULL FROM users"
        dbConn.exec sql "SELECT NULL FROM pet"

  test "Custom DB":
    withCustomDb(customDbHost, dbUser, dbPassword, dbDatabase):
      createTables(force=true)

    proc getCols(table: string): seq[string] =
      let query = sql "SELECT column_name FROM information_schema.columns WHERE table_name = $1 ORDER BY column_name"

      withCustomDb(customDbHost, dbUser, dbPassword, dbDatabase):
        for col in dbConn.getAllRows(query, table):
          result.add $col[0]

    check getCols("users") == sorted @["id", "email", "lastlogin"]
    check getCols("pet") == sorted @["id", "name", "age", "ownerid"]

    withCustomDb(customDbHost, dbUser, dbPassword, dbDatabase):
      dropTables()

      expect DbError:
        dbConn.exec sql "SELECT NULL FROM users"
        dbConn.exec sql "SELECT NULL FROM pet"
