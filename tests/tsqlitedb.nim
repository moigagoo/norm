discard """
  action: "run"
  exitcode: 0
"""
import unittest
import os
import strutils

import norm/[model, sqlite]

import models


const dbFile = getTempDir() / "test.db"


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
