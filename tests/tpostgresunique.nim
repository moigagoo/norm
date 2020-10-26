import unittest
import strutils

import norm/[model, postgres]

import models

const
  dbHost = "postgres"
  dbUser = "postgres"
  dbPassword = "postgres"
  dbDatabase = "postgres"

suite "Unique constraint":
  proc resetDb =
    let dbConn = open(dbHost, dbUser, dbPassword, "template1")
    dbConn.exec(sql "DROP DATABASE IF EXISTS $#" % dbDatabase)
    dbConn.exec(sql "CREATE DATABASE $#" % dbDatabase)
    close dbConn

  setup:
    resetDb()
    let dbConn = open(dbHost, dbUser, dbPassword, dbDatabase)

    dbConn.createTables(newPerson())

  teardown:
    close dbConn
    resetDb()

  test "Duplicate insert":
    block:
      let
        toy = newToy(123.45)
        pet = newPet("cat", toy)

      var person = newPerson("Alice", pet)
      dbConn.insert(person)
      check person.id == 1

    block:
      var alice = newPerson()
      dbConn.select(alice, "name = $1", "Alice")
      check alice.name == "Alice"
      check alice.id == 1

    block:
      let
        toy = newToy(36.66)
        pet = newPet("dog", toy)

      var person = newPerson("Alice", pet)

      expect DbError:
        dbConn.insert(person)
