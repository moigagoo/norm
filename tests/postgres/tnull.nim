import std/[os, unittest, options, strutils]

import norm/[model, postgres]

import ../models


const
  dbHost = getEnv("PGHOST", "postgres")
  dbUser = getEnv("PGUSER", "postgres")
  dbPassword = getEnv("PGPASSWORD", "postgres")
  dbDatabase = getEnv("PGDATABASE", "postgres")


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

  test "Get row, nested models, NULL foreign key, container is ``none Model``":
    var
      inpPerson = newPerson("Alice", none Pet)
      outPerson = newPerson("", none Pet)

    dbConn.insert(inpPerson)

    dbConn.select(outPerson, """"Person".id = $1""", inpPerson.id)

    check outPerson === inpPerson
