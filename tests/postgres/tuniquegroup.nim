import std/[os, unittest, options, strutils]

import norm/[model, postgres]

import ../models


const
  dbHost = getEnv("PGHOST", "postgres")
  dbUser = getEnv("PGUSER", "postgres")
  dbPassword = getEnv("PGPASSWORD", "postgres")
  dbDatabase = getEnv("PGDATABASE", "postgres")


suite "Unique constraint on multiple columns":
  proc resetDb =
    let dbConn = open(dbHost, dbUser, dbPassword, "template1")
    dbConn.exec(sql "DROP DATABASE IF EXISTS $#" % dbDatabase)
    dbConn.exec(sql "CREATE DATABASE $#" % dbDatabase)
    close dbConn

  setup:
    resetDb()
    let dbConn = open(dbHost, dbUser, dbPassword, dbDatabase)

    dbConn.createTables(newAccount())

  teardown:
    close dbConn
    resetDb()

  test "Insert non-duplicate values":
    var
      account1 = newAccount(1, "foo@example.com")
      account2 = newAccount(1, "bar@example.com")
      account3 = newAccount(0, "foo@example.com")

    dbConn.insert(account1)
    dbConn.insert(account2)
    dbConn.insert(account3)

    var accounts = @[newAccount()]
    dbConn.selectAll(accounts)

    check len(accounts) == 3

  test "Insert duplicate values":
    var
      account1 = newAccount(1, "foo@example.com")
      account2 = newAccount(1, "foo@example.com")

    dbConn.insert(account1)

    expect DbError:
      dbConn.insert(account2)

