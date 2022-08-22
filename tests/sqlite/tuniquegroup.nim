import std/[unittest, os, options, strutils]

import norm/[model, sqlite]

import ../models


const dbFile = "test.db"


suite "Unique constraint on multiple columns":
  setup:
    removeFile dbFile

    let dbConn = open(dbFile, "", "", "")

    dbConn.createTables(newAccount())

  teardown:
    close dbConn
    removeFile dbFile

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

  test "Insert duplicate values, ignore on conflict":
    var
      account1 = newAccount(1, "foo@example.com")
      account2 = newAccount(1, "foo@example.com")

    dbConn.insert(account1)
    dbConn.insert(account2, conflictPolicy = cpIgnore)

    let rows = dbConn.getAllRows(sql"SELECT status, email, id FROM Account")

    check rows.len == 1
    check rows[0] == @[?account1.status, ?account1.email, ?account1.id]

  test "Insert duplicate values, replace on conflict":
    var
      account1 = newAccount(1, "foo@example.com")
      account2 = newAccount(1, "foo@example.com")

    dbConn.insert(account1)
    dbConn.insert(account2, conflictPolicy = cpReplace)

    let rows = dbConn.getAllRows(sql"SELECT status, email, id FROM Account")

    check rows.len == 1
    check rows[0] == @[?account2.status, ?account2.email, ?account2.id]

