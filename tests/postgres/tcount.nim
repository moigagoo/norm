import std/[unittest, strutils, sugar, options]

import norm/[model, postgres]

import ../models


const
  dbHost = "postgres"
  dbUser = "postgres"
  dbPassword = "postgres"
  dbDatabase = "postgres"


suite "Row CRUD":
  proc resetDb =
    let dbConn = open(dbHost, dbUser, dbPassword, "template1")
    dbConn.exec(sql "DROP DATABASE IF EXISTS $#" % dbDatabase)
    dbConn.exec(sql "CREATE DATABASE $#" % dbDatabase)
    close dbConn

  setup:
    resetDb()
    let dbConn = open(dbHost, dbUser, dbPassword, dbDatabase)

    var
      spot = newPet("dog", newToy())
      alice = newPerson("Alice", spot)
      bob = newPerson("Bob", none Pet)
      jeff = newPerson("Jeff", spot)

    dbConn.createTables(newPerson())

    discard @[alice, bob, jeff].dup:
      dbConn.insert

  teardown:
    close dbConn
    resetDb()

  test "ALL":
    check dbConn.count(Pet) == 1
    check dbConn.count(Person, "name") == 3
    check dbConn.count(Person, "pet") == 2

  test "DISTINCT":
    check dbConn.count(Person, "name", dist = true) == 3
    check dbConn.count(Person, "pet", dist = true) == 1

  test "Conditions":
    check dbConn.count(Person, "*", dist = false, "name ILIKE $1", "alice") == 1
    check dbConn.count(Person, "pet", dist = true, "pet = $1", 1) == 1
