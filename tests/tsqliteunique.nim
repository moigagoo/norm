import unittest
import strutils
import options
import os

import norm/[model, sqlite]

import models

const dbFile = "test.db"

proc duplicateInsert(dbConn: DbConn)

suite "Table creation":
  proc resetDb =
    removeFile dbFile
    let dbConn = open(dbFile, "", "", "")
    dbConn.createTables(newPerson())
    close dbConn

  setup:
    resetDb()
    let dbConn = open(dbFile, "", "", "")

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
