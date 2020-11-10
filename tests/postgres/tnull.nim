discard """
  action: "run"
  exitcode: 0
"""

import unittest
import options
import strutils

import norm/[model, postgres]

import ../models


const
  dbHost = "postgres"
  dbUser = "postgres"
  dbPassword = "postgres"
  dbDatabase = "postgres"


suite "``NULL`` foreign keys":
  proc resetDb =
    let dbConn = open(dbHost, dbUser, dbPassword, "template1")
    dbConn.exec(sql "DROP DATABASE IF EXISTS $#" % dbDatabase)
    dbConn.exec(sql "CREATE DATABASE $#" % dbDatabase)
    close dbConn

  setup:
    resetDb()
    let dbConn = open(dbHost, dbUser, dbPassword, dbDatabase)

    dbConn.createTables(newPerson())

  teardown:
    close dbConn
    resetDb()

  test "Get row, nested models, NULL foreign key, container is ``some Model``":
    var
      inpPerson = newPerson("Alice", none Pet)
      outPerson = newPerson("", newPet())

    dbConn.insert(inpPerson)

    dbConn.select(outPerson, """"Person".id = $1""", inpPerson.id)

    check outPerson === inpPerson
