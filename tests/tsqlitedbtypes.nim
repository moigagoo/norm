discard """
  action: "run"
  exitcode: 0
"""
import unittest
import os
import times
import sugar

import norm/[model, sqlite]

import models


const dbFile = getTempDir() / "test.db"


suite "Import dbTypes from norm/private/sqlite/dbtypes":
  setup:
    removeFile dbFile

    putEnv(dbHostEnv, dbFile)

    withDb:
      db.createTables(newUser())

  teardown:
    delEnv(dbHostEnv)
    removeFile dbFile

  test "dbValue[DateTime] is imported":
    withDb:
      let users = @[newUser()].dup:
        db.select("""lastLogin <= ?""", ?now())

      check len(users) == 0
