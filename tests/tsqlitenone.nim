import unittest
import os
import options
import sugar

import norm/[model, sqlite]

import models


const dbFile = "test.db"


suite "none Model field handling":
  setup:
    removeFile dbFile

    let dbConn = open(dbFile, "", "", "")

  teardown:
    close dbConn
    removeFile dbFile

  test "Create tables":
    dbConn.createTables(newPerson("", none Pet))

    let rows = dbConn.getAllRows(sql "SELECT name FROM sqlite_master WHERE type = 'table'")

    check rows.len == 1
    check rows[0] == @[?"Person"]

  test "Insert row":
    dbConn.createTables(newPerson())

    var person = newPerson("Alice", none Pet)

    dbConn.insert(person)

    let rows = dbConn.getAllRows(sql"SELECT name, pet FROM Person")

    check rows.len == 1
    check rows[0] == @[?"Alice", ?nil]

  test "Get row":
    dbConn.createTables(newPerson())

    var
      inpPerson = newPerson("Alice", none Pet)
      outPerson = newPerson("", none Pet)

    dbConn.insert(inpPerson)

    dbConn.select(outPerson, "Person.id = ?", inpPerson.id)

    check outPerson === inpPerson

  test "Update row":
    dbConn.createTables(newPerson())

    var
      inpPerson = newPerson("Alice", none Pet)
      outPerson = newPerson()
      pet = newPet("cat", newToy(123.45))

    dbConn.insert(inpPerson)
    dbConn.insert(pet)

    inpPerson.pet = some pet
    dbConn.update(inpPerson)

    dbConn.select(outPerson, "Person.id = ?", inpPerson.id)

    check outPerson === inpPerson

  test "Delete row":
    dbConn.createTables(newPerson())

    var person = newPerson("Alice", none Pet)

    dbConn.insert(person)
    dbConn.delete(person)

    expect KeyError:
      discard newPerson().dup:
        dbConn.select("Person.name = ?", "Alice")
