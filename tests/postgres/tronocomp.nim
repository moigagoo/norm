discard """
  action: "reject"
  errormsg: "can't use mutating procs with read-only models"
  file: "model.nim"
"""

import std/[unittest, strutils, sugar]

import norm/[model, postgres]

import ../models


const
  dbHost = "postgres"
  dbUser = "postgres"
  dbPassword = "postgres"
  dbDatabase = "postgres"


suite "Read-only models, mutating procs":
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

  test "Insert row":
    var personName = PersonName(name: "Name")

    dbConn.insert(personName)

