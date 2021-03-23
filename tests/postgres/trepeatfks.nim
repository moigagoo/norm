import std/[unittest, strutils]

import norm/[model, postgres]

import ../models


const
  dbHost = "postgres"
  dbUser = "postgres"
  dbPassword = "postgres"
  dbDatabase = "postgres"


suite "Model with repeating foreign keys":
  proc resetDb =
    let dbConn = open(dbHost, dbUser, dbPassword, "template1")
    dbConn.exec(sql "DROP DATABASE IF EXISTS $#" % dbDatabase)
    dbConn.exec(sql "CREATE DATABASE $#" % dbDatabase)
    close dbConn

  setup:
    resetDb()

    let dbConn = open(dbHost, dbUser, dbPassword, dbDatabase)

    dbConn.createTables(newPlayfulPet())

  teardown:
    close dbConn
    resetDb()

  test "Get row":
    var
      inpPlayfulPet = newPlayfulPet("cat", newToy(123.45), newToy(456.78))
      outPlayfulPet = newPlayfulPet()

    dbConn.insert(inpPlayfulPet)

    dbConn.select(outPlayfulPet, """"PlayfulPet".id = $1""", inpPlayfulPet.id)

    check outPlayfulPet === inpPlayfulPet
