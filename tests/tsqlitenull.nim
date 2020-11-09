import unittest
import os
import options

import norm/[model, sqlite]

import models


const dbFile = "test.db"


suite "``NULL`` foreign keys":
  setup:
    removeFile dbFile

    let dbConn = open(dbFile, "", "", "")

    dbConn.createTables(newPerson())

  teardown:
    close dbConn
    removeFile dbFile

  test "Get row, nested models, NULL foreign key, container is ``some Model``":
    var
      inpPerson = newPerson("Alice", none Pet)
      outPerson = newPerson("", newPet())

    dbConn.insert(inpPerson)

    dbConn.select(outPerson, "Person.id = ?", inpPerson.id)

    check outPerson === inpPerson
