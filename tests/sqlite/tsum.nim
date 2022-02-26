import std/[unittest, os, sugar, options]

import norm/sqlite

import ../models


const dbFile = "test.db"


suite "Row sum":
  setup:
    removeFile dbFile

    let dbConn = open(dbFile, "", "", "")

    dbConn.createTables(newToy())

    discard @[newToy(123.45), newToy(123.45), newToy(67.89)].dup:
      dbConn.insert

  teardown:
    close dbConn
    removeFile dbFile

  test "ALL":
    check dbConn.sum(Toy, "price") == 123.45 + 123.45 + 67.89

  test "DISTINCT":
    check dbConn.sum(Toy, "price", dist = true) == 123.45 + 67.89

  test "Conditions":
    check dbConn.sum(Toy, "price", dist = false, "price > ?", 123) == 123.45 + 123.45
    check dbConn.sum(Toy, "price", dist = true, "price > ?", 123) == 123.45

