import unittest
import os
import sugar

import norm/[model, sqlite]

import models


const dbFile = "test.db"


suite "Relation triangle":
  setup:
    removeFile dbFile

    let dbConn = open(dbFile, "", "", "")

    dbConn.createTables(newToyPet())

    var
      toy = newToy(123.45)
      pet = newPet("cat", toy)
      toyPet = newToyPet(toy, pet)

    dbConn.insert(toyPet)

  teardown:
    close dbConn
    removeFile dbFile

  test "Get row":
    let outToyPet = newToyPet().dup:
      dbConn.select(""""ToyPet".id = $1""", toyPet.id)

    check outToyPet === toyPet
