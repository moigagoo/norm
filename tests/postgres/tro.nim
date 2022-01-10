import std/[unittest, strutils, sugar, options]

import norm/[model, postgres]

import ../models


const
  dbHost = "postgres"
  dbUser = "postgres"
  dbPassword = "postgres"
  dbDatabase = "postgres"


suite "Read-only models, non-mutating procs":
  proc resetDb =
    let dbConn = open(dbHost, dbUser, dbPassword, "template1")
    dbConn.exec(sql "DROP DATABASE IF EXISTS $#" % dbDatabase)
    dbConn.exec(sql "CREATE DATABASE $#" % dbDatabase)
    close dbConn

  setup:
    resetDb()
    let dbConn = open(dbHost, dbUser, dbPassword, dbDatabase)

    var
      alice = newPerson("Alice", none Pet)
      bob = newPerson("Bob", none Pet)

    dbConn.createTables(newPerson())
    dbConn.insert(alice)
    dbConn.insert(bob)

  teardown:
    close dbConn
    resetDb()

  test "Select rows":
    var personNames = @[newPersonName()]

    dbConn.selectAll(personNames)

    assert len(personNames) == 2
    assert personNames[0].name == "Alice"
    assert personNames[1].name == "Bob"

