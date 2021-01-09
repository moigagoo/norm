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
    let dbConn = open(dbHost, dbUser, dbPassword, dbDatabase)

    dbConn.createTables(newUser())

  teardown:
    close dbConn
    resetDb()

  test "dbValue[DateTime] is imported":
    let users = @[newUser()].dup:
      dbConn.select("""lastLogin <= $1""", ?now())

    check len(users) == 0
