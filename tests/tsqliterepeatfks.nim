import unittest
import os
import strutils
import options

import norm/[model, sqlite]

import models


const dbFile = "test.db"


suite "Model with repeating foreign keys":
  setup:
    removeFile dbFile

    let dbConn = open(dbFile, "", "", "")

    dbConn.createTables(newPlayfulPet())

  teardown:
    close dbConn
    removeFile dbFile

  test "Get row":
    var
      inpPlayfulPet = newPlayfulPet("cat", newToy(123.45), newToy(456.78))
      outPlayfulPet = newPlayfulPet()

    dbConn.insert(inpPlayfulPet)

    dbConn.select(outPlayfulPet, """"PlayfulPet".id = ?""", inpPlayfulPet.id)

    check outPlayfulPet === inpPlayfulPet
