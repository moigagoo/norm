import std/[unittest, os, strutils]

import norm/[model, sqlite]

import ../models


const dbFile = "test.db"


suite "Database manipulation":
  setup:
    removeFile dbFile

    putEnv(dbHostEnv, dbFile)

    withDb:
      db.createTables(newToy())

  teardown:
    delEnv(dbHostEnv)
    removeFile dbFile

  test "Drop DB":
    dropDb()

    check not fileExists(dbFile)

