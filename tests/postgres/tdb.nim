import std/[unittest, os, strutils]

import norm/[model, postgres]

import ../models


const
  dbHost = "postgres"
  dbUser = "postgres"
  dbPassword = "postgres"
  dbDatabase = "postgres"


suite "Database manipulation":
  proc resetDb =
    let dbConn = open(dbHost, dbUser, dbPassword, "template1")
    dbConn.exec(sql "DROP DATABASE IF EXISTS $#" % dbDatabase)
    dbConn.exec(sql "CREATE DATABASE $#" % dbDatabase)
    close dbConn

  setup:
    resetDb()

    putEnv(dbHostEnv, dbHost)
    putEnv(dbUserEnv, dbUser)
    putEnv(dbPassEnv, dbPassword)
    putEnv(dbNameEnv, dbDatabase)

    withDb:
      db.createTables(newToy())

  teardown:
    delEnv(dbHostEnv)
    delEnv(dbUserEnv)
    delEnv(dbPassEnv)
    delEnv(dbNameEnv)

    resetDb()

  test "Drop DB":
    dropDb()

    expect DbError:
      withDb:
        discard
