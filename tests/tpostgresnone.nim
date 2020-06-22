import unittest
import strutils
import options
import sugar

import norm/[model, postgres]

import models


const
  dbHost = "postgres"
  dbUser = "postgres"
  dbPassword = "postgres"
  dbDatabase = "postgres"


suite "none Model field handling":
  proc resetDb =
    let dbConn = open(dbHost, dbUser, dbPassword, "template1")
    dbConn.exec(sql "DROP DATABASE IF EXISTS $#" % dbDatabase)
    dbConn.exec(sql "CREATE DATABASE $#" % dbDatabase)
    close dbConn

  setup:
    resetDb()
    let dbConn = open(dbHost, dbUser, dbPassword, dbDatabase)

  teardown:
    close dbConn
    resetDb()

  test "Create tables":
    dbConn.createTables(newPet())
    dbConn.createTables(newPerson("", none Pet))

    let rows = dbConn.getAllRows(sql"SELECT table_name::text FROM information_schema.tables WHERE table_schema = 'public'")

    check rows.len == 3
    check @[?"Person"] in rows

  test "Insert row":
    dbConn.createTables(newPerson())

    var person = newPerson("Alice", none Pet)

    dbConn.insert(person)

    let rows = dbConn.getAllRows(sql"""SELECT name, pet FROM "Person"""")

    check rows.len == 1
    check rows[0] == @[?"Alice", ?nil]

  test "Get row":
    dbConn.createTables(newPerson())

    var
      inpPerson = newPerson("Alice", none Pet)
      outPerson = newPerson("", none Pet)

    dbConn.insert(inpPerson)

    dbConn.select(outPerson, """"Person".id = $1""", inpPerson.id)

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

    dbConn.select(outPerson, """"Person".id = $1""", inpPerson.id)

    check outPerson === inpPerson

  test "Delete row":
    dbConn.createTables(newPerson())

    var person = newPerson("Alice", none Pet)

    dbConn.insert(person)
    dbConn.delete(person)

    expect KeyError:
      discard newPerson().dup:
        dbConn.select(""""Person".name = $1""", "Alice")
