import std/[unittest, os, strutils]

import norm/[model, sqlite]

import ../models


const dbFile = "test.db"


suite "DB config from environment variables":
  setup:
    removeFile dbFile
    putEnv(dbHostEnv, dbFile)

  teardown:
    delEnv(dbHostEnv)
    removeFile dbFile

  test "Explicit DB connection":
    let db = getDb()

    defer:
      close db

    db.createTables(newToy())

    let qry = "PRAGMA table_info($#);"

    check db.getAllRows(sql qry % "Toy") == @[
      @[?0, ?"price", ?"FLOAT", ?1, ?nil, ?0],
      @[?1, ?"id", ?"INTEGER", ?1, ?nil, ?1],
    ]

  test "Implicit DB connection":
    withDb:
      db.createTables(newToy())

      let qry = "PRAGMA table_info($#);"

      check db.getAllRows(sql qry % "Toy") == @[
        @[?0, ?"price", ?"FLOAT", ?1, ?nil, ?0],
        @[?1, ?"id", ?"INTEGER", ?1, ?nil, ?1],
      ]

