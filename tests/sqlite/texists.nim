import std/[unittest, os, sugar, options]

import norm/sqlite

import ../models


const dbFile = "test.db"


suite "Row existance check":
  setup:
    removeFile dbFile

    let dbConn = open(dbFile, "", "", "")

    dbConn.createTables(newPet())

    discard newPet("dog", newToy()).dup:
      dbConn.insert()

  teardown:
    close dbConn
    removeFile dbFile

  test "Row exists":
    check dbConn.exists(Pet, "species = ?", "dog")

  test "Row doesn't exist":
    check not dbConn.exists(Pet, "species = ?", "cat")

