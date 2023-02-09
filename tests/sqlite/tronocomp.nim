discard """
  action: "reject"
  errormsg: "Can't use mutating procs with read-only models"
  file: "model.nim"
"""

import std/[unittest, os, strutils]

import norm/[model, sqlite]

import ../models


const dbFile = "test.db"


suite "Read-only models, mutating procs":
  setup:
    removeFile dbFile

    putEnv(dbHostEnv, dbFile)

    withDb:
      db.createTables(newPerson())

  teardown:
    delEnv(dbHostEnv)
    removeFile dbFile

  test "Insert row":
    var personName = PersonName(name: "Name")

    withDb:
      db.insert(personName)

