import std/[os, unittest, strutils, sugar, options]

import norm/[model, postgres]

import ../models


const
  dbHost = getEnv("PGHOST", "postgres")
  dbUser = getEnv("PGUSER", "postgres")
  dbPassword = getEnv("PGPASSWORD", "postgres")
  dbDatabase = getEnv("PGDATABASE", "postgres")


suite "Row sum":
  proc resetDb =
    let dbConn = open(dbHost, dbUser, dbPassword, "template1")
    dbConn.exec(sql "DROP DATABASE IF EXISTS $#" % dbDatabase)
    dbConn.exec(sql "CREATE DATABASE $#" % dbDatabase)
    close dbConn

  setup:
    resetDb()
    let dbConn = open(dbHost, dbUser, dbPassword, dbDatabase)

    dbConn.createTables(newToy())

    discard @[newToy(123.45), newToy(123.45), newToy(67.89)].dup:
      dbConn.insert

  teardown:
    close dbConn
    resetDb()

  test "ALL":
    check dbConn.sum(Toy, "price") == 123.45 + 123.45 + 67.89

  test "DISTINCT":
    check dbConn.sum(Toy, "price", dist = true) == 123.45 + 67.89

  test "Conditions":
    check dbConn.sum(Toy, "price", dist = false, "price > $1", 123) == 123.45 + 123.45
    check dbConn.sum(Toy, "price", dist = true, "price > $1", 123) == 123.45

