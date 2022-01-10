import std/[unittest, os, strutils, options]

import norm/[model, sqlite]

import ../models


const dbFile = "test.db"


suite "Read-only models, non-mutating procs":
  setup:
    removeFile dbFile

    putEnv(dbHostEnv, dbFile)

    var
      alice = newPerson("Alice", none Pet)
      bob = newPerson("Bob", none Pet)

    withDb:
      db.createTables(newPerson())
      db.insert(alice)
      db.insert(bob)

  teardown:
    delEnv(dbHostEnv)
    removeFile dbFile

  test "Select rows":
    var personNames = @[newPersonName()]

    withDb:
      db.selectAll(personNames)

    assert len(personNames) == 2
    assert personNames[0].name == "Alice"
    assert personNames[1].name == "Bob"

