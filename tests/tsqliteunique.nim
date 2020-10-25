import unittest
import strutils
import options
import os

import norm/[model, sqlite]

import models

const dbFile = "test.db"

suite "Unique constraint":
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
    block:
      let
        toy = newToy(123.45)
        pet = newPet("cat", toy)

      var person = newPerson("Alice", pet)
      dbConn.insert(person)
      check person.id == 1

    block:
      var alice = newPerson()
      dbConn.select(alice, "Person.name = $1", "Alice")
      check alice.name == "Alice"
      check alice.id == 1

    block:
      let
        toy = newToy(36.66)
        pet = newPet("dog", toy)

      var person = newPerson("Alice", pet)

      expect DbError:
        dbConn.insert(person)
