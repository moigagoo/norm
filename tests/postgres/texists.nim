import std/[os, unittest, strutils, sugar, options]

import norm/[model, postgres]

import ../models


const
  dbHost = getEnv("PGHOST", "postgres")
  dbUser = getEnv("PGUSER", "postgres")
  dbPassword = getEnv("PGPASSWORD", "postgres")
  dbDatabase = getEnv("PGDATABASE", "postgres")


suite "Row existance check":
  proc resetDb =
    let dbConn = open(dbHost, dbUser, dbPassword, "template1")
    dbConn.exec(sql "DROP DATABASE IF EXISTS $#" % dbDatabase)
    dbConn.exec(sql "CREATE DATABASE $#" % dbDatabase)
    close dbConn

  setup:
    resetDb()
    let dbConn = open(dbHost, dbUser, dbPassword, dbDatabase)

    dbConn.createTables(newPet())

    discard newPet("dog", newToy()).dup:
      dbConn.insert()

  teardown:
    close dbConn
    resetDb()

  test "Row exists":
    check dbConn.exists(Pet, "species = $1", "dog")

  test "Row doesn't exist":
    check not dbConn.exists(Pet, "species = $1", "cat")

