discard """
  action: "run"
  exitcode: 0
"""

import unittest
import os
import strutils

import norm/[model, postgres]

import ../models


const
  dbHost = "postgres"
  dbUser = "postgres"
  dbPassword = "postgres"
  dbDatabase = "postgres"


suite "DB config from environment variables":
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

  teardown:
    delEnv(dbHostEnv)
    delEnv(dbUserEnv)
    delEnv(dbPassEnv)
    delEnv(dbNameEnv)

    resetDb()

  test "Explicit DB connection":
    let db = getDb()

    defer:
      close db

    db.createTables(newToy())

    let qry = sql """SELECT column_name::text, data_type::text
      FROM information_schema.columns
      WHERE table_name = $1
      ORDER BY column_name"""

    check db.getAllRows(qry, "Toy") == @[
      @[?"id", ?"integer"],
      @[?"price", ?"real"]
    ]

  test "Implicit DB connection":
    withDb:
      db.createTables(newToy())

      let qry = sql """SELECT column_name::text, data_type::text
        FROM information_schema.columns
        WHERE table_name = $1
        ORDER BY column_name"""

      check db.getAllRows(qry, "Toy") == @[
        @[?"id", ?"integer"],
        @[?"price", ?"real"]
      ]
