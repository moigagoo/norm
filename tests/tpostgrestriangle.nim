import unittest
import strutils
import sugar

import norm/[model, postgres]

import models


const
  dbHost = "postgres"
  dbUser = "postgres"
  dbPassword = "postgres"
  dbDatabase = "postgres"


suite "Relation triangle":
  proc resetDb =
    let dbConn = open(dbHost, dbUser, dbPassword, "template1")
    dbConn.exec(sql "DROP DATABASE IF EXISTS $#" % dbDatabase)
    dbConn.exec(sql "CREATE DATABASE $#" % dbDatabase)
    close dbConn

  setup:
    resetDb()
    let dbConn = open(dbHost, dbUser, dbPassword, dbDatabase)

    dbConn.createTables(newToyPet())

    var
      toy = newToy(123.45)
      pet = newPet("cat", toy)
      toyPet = newToyPet(toy, pet)

    dbConn.insert(toyPet)

  teardown:
    close dbConn
    resetDb()

  test "Get row":
    let outToyPet = newToyPet().dup:
      dbConn.select(""""ToyPet".id = $1""", toyPet.id)

    check outToyPet === toyPet
