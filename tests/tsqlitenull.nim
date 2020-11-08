discard """
  action: "run"
  exitcode: 0
"""
import unittest
import os
import options
import sugar

import norm/[model, sqlite]

import models


const dbFile = getTempDir() / "test.db"


suite "``NULL`` foreign keys":
  setup:
    removeFile dbFile

    let dbConn = open(dbFile, "", "", "")

  teardown:
    close dbConn
    removeFile dbFile

  test "Get row, nested models, NULL foreign key, container is ``some Model``":
    dbConn.createTables(newPerson())

    var
      inpPerson = newPerson("Alice", none Pet)
      outPerson = newPerson("", newPet())

    dbConn.insert(inpPerson)

    dbConn.select(outPerson, "Person.id = ?", inpPerson.id)

    check outPerson === inpPerson
