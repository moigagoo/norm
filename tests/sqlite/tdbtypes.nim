import unittest
import os
import times
import sugar

import norm/[model, sqlite]

import ../models


const dbFile = "test.db"


suite "Import dbTypes from norm/private/sqlite/dbtypes":
  setup:
    removeFile dbFile

    let dbConn = open(dbFile, "", "", "")

    dbConn.createTables(newUser())

  teardown:
    close dbConn
    removeFile dbFile

  test "dbValue[DateTime] is imported":
    let users = @[newUser()].dup:
      dbConn.select("""lastLogin <= ?""", ?now())

    check len(users) == 0
