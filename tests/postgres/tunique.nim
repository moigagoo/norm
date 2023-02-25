import std/[os, unittest, strutils]

import norm/[model, postgres]

import ../models


const
  dbHost = getEnv("PGHOST", "postgres")
  dbUser = getEnv("PGUSER", "postgres")
  dbPassword = getEnv("PGPASSWORD", "postgres")
  dbDatabase = getEnv("PGDATABASE", "postgres")


suite "Unique fields":
  proc resetDb =
    let dbConn = open(dbHost, dbUser, dbPassword, "template1")
    dbConn.exec(sql "DROP DATABASE IF EXISTS $#" % dbDatabase)
    dbConn.exec(sql "CREATE DATABASE $#" % dbDatabase)
    close dbConn

  setup:
    resetDb()
    let dbConn = open(dbHost, dbUser, dbPassword, dbDatabase)

    dbConn.createTables(newPerson())

  teardown:
    close dbConn
    resetDb()

  test "Insert duplicate values":
    var
      person1 = newPerson("Alice", newPet("cat", newToy(123.45)))
      person2 = newPerson("Alice", newPet("dog", newToy(678.90)))

    dbConn.insert(person1)

    expect DbError:
      dbConn.insert(person2)
