import unittest
import os
import strutils
import times
import sugar

import norm/[model, postgres]

import ../models


const
  dbHost = "postgres"
  dbUser = "postgres"
  dbPassword = "postgres"
  dbDatabase = "postgres"


suite "Import dbTypes from norm/private/postgres/dbtypes":
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
      db.createTables(newUser())

  teardown:
    delEnv(dbHostEnv)
    delEnv(dbUserEnv)
    delEnv(dbPassEnv)
    delEnv(dbNameEnv)

    resetDb()

  test "dbValue[DateTime] is imported":
    withDb:
      let users = @[newUser()].dup:
        db.select("""lastLogin <= $1""", ?now())

      check len(users) == 0
