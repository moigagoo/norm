import std/[unittest, os, options, strutils]

import norm/[model, sqlite]

import ../models


const dbFile = "test.db"


suite "Unique constraint":
  setup:
    removeFile dbFile

    let dbConn = open(dbFile, "", "", "")

    dbConn.createTables(newPerson())

  teardown:
    close dbConn
    removeFile dbFile

  test "Insert duplicate values":
    var
      person1 = newPerson("Alice", newPet("cat", newToy(123.45)))
      person2 = newPerson("Alice", newPet("dog", newToy(678.90)))

    dbConn.insert(person1)

    expect DbError:
      dbConn.insert(person2)
