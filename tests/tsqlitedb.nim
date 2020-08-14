import unittest
import os
import strutils

import norm/[model, sqlite]

import models


const dbFile = "test.db"


suite "Drop DB defined in environment variables":
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
