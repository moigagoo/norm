import unittest
import strutils

import norm/[model, postgres]

import models


const
  dbHost = "postgres"
  dbUser = "postgres"
  dbPassword = "postgres"
  dbDatabase = "postgres"

proc duplicateInsert(dbConn: DbConn)

suite "Table creation":
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

  test "Duplicate insert":
    # Check test fail with DbError
    expect DbError:
      duplicateInsert(dbConn)

proc duplicateInsert(dbConn: DbConn)=
  block:
    let
      toy = newToy(123.45)
      pet = newPet("cat", toy)

    var person = newPerson("Alice", pet)
    dbConn.insert(person)
    check true

  block:
    let
      toy = newToy(36.66)
      pet = newPet("dog", toy)

    var person = newPerson("Alice", pet)
    dbConn.insert(person)
    # Check that test does not reach this point
    check false
