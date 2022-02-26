import std/[unittest, os, sugar, options]

import norm/sqlite

import ../models


const dbFile = "test.db"


suite "Count rows":
  setup:
    removeFile dbFile

    let dbConn = open(dbFile, "", "", "")

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
    removeFile dbFile

  test "ALL":
    check dbConn.count(Pet) == 1
    check dbConn.count(Person, "name") == 3
    check dbConn.count(Person, "pet") == 2

  test "DISTINCT":
    check dbConn.count(Person, "name", dist = true) == 3
    check dbConn.count(Person, "pet", dist = true) == 1

  test "Conditions":
    check dbConn.count(Person, "*", dist = false, "name LIKE ?", "alice") == 1
    check dbConn.count(Person, "pet", dist = true, "pet = ?", 1) == 1

