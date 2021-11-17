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

  test "Insert duplicate values, ignore on conflict":
    var
      person1 = newPerson("Alice", newPet("cat", newToy(123.45)))
      person2 = newPerson("Alice", newPet("dog", newToy(678.90)))

    dbConn.insert(person1)
    dbConn.insert(person2, conflictPolicy = cpIgnore)

    let rows = dbConn.getAllRows(sql"SELECT name, id FROM Person")

    check rows.len == 1
    check rows[0] == @[?person1.name, ?person1.id]

  test "Insert duplicate values, replace on conflict":
    var
      person1 = newPerson("Alice", newPet("cat", newToy(123.45)))
      person2 = newPerson("Alice", newPet("dog", newToy(678.90)))

    dbConn.insert(person1)
    dbConn.insert(person2, conflictPolicy = cpReplace)

    let rows = dbConn.getAllRows(sql"SELECT name, id FROM Person")

    check rows.len == 1
    check rows[0] == @[?person2.name, ?person2.id]

