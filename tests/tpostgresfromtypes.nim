import unittest

import os, strutils, sequtils, times

import norm/postgres

import user, pet


const
  dbHost = "postgres_1"
  customDbHost = "postgres_2"


dbFromTypes(dbHost, "postgres", "", "postgres", [User, Pet])


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
      let query = sql "SELECT column_name FROM information_schema.columns WHERE table_name = ?"

      check dbConn.getAllRows(query, "users") == @[@["id"], @["email"], @["lastlogin"]]
      check dbConn.getAllRows(query, "pet") == @[@["id"], @["name"], @["age"], @["ownerid"]]

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
    withCustomDb(customDbHost, "postgres", "", "postgres"):
      createTables(force=true)

    withCustomDb(customDbHost, "postgres", "", "postgres"):
      let query = sql "SELECT column_name FROM information_schema.columns WHERE table_name = ?"

      check dbConn.getAllRows(query, "users") == @[@["id"], @["email"], @["lastlogin"]]
      check dbConn.getAllRows(query, "pet") == @[@["id"], @["name"], @["age"], @["ownerid"]]

    withCustomDb(customDbHost, "postgres", "", "postgres"):
      dropTables()

      expect DbError:
        dbConn.exec sql "SELECT NULL FROM user"
        dbConn.exec sql "SELECT NULL FROM pet"
