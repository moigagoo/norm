import unittest
import os
import strutils
import sugar
import options

import norm/[model, sqlite]

import models


const dbFile = "test.db"


suite "Transactions":
  setup:
    removeFile dbFile

    let dbConn = open(dbFile, "", "", "")

    dbConn.createTables(Toy())

  teardown:
    close dbConn
    removeFile dbFile

  test "Transaction, successful execution":
    var toy = initToy(123.45)

    dbConn.transaction:
      dbConn.insert(toy)

    check toy.id > 0

    let rows = dbConn.getAllRows(sql"SELECT price, id FROM Toy")

    check rows.len == 1
    check rows[0] == @[?123.45, ?toy.id]

  test "Transaction, rollback on exception":
    expect ValueError:
      dbConn.transaction:
        let toy = Toy().dup(dbConn.insert)

        raise newException(ValueError, "Something went wrong")

    let rows = dbConn.getAllRows(sql"SELECT price, id FROM Toy")
    check rows.len == 0

  test "Transaction, manual rollback":
    expect RollbackError:
      dbConn.transaction:
        let toy = Toy().dup(dbConn.insert)
        rollback()

    let rows = dbConn.getAllRows(sql"SELECT price, id FROM Toy")
    check rows.len == 0
