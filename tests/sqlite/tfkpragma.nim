import strutils
import unittest
import os

import norm/[model, sqlite]

import ../models


const dbFile = "test.db"


suite "``fk`` pragma":
  setup:
    removeFile dbFile

    let dbConn = open(dbFile, "", "", "")

    dbConn.createTables(newUser())
    dbConn.createTables(newCustomer())

  teardown:
    close dbConn
    removeFile dbFile

  test "Insert rows":
    var user = newUser()
    dbConn.insert user

    var customer = newCustomer(user.id, "test@test.test")
    dbConn.insert customer

    check user.id > 0
    check customer.id > 0

    let
      userRows = dbConn.getAllRows(sql"""SELECT lastLogin, id FROM "User"""")
      customerRows = dbConn.getAllRows(sql"""SELECT userId, email, id FROM "Customer"""")

    check userRows.len == 1
    check userRows[0] == @[?user.lastLogin, ?user.id]

    check customerRows.len == 1
    check customerRows[0] == @[?user.id, ?customer.email, ?customer.id]

  test "Get rows":
    var
      userA = newUser()
      userB = newUser()

    dbConn.insert userA
    dbConn.insert userB

    var
      inpCustomers = @[
        newCustomer(userA.id, "a@test.test"),
        newCustomer(userA.id, "b@test.test"),
        newCustomer(userB.id, "c@test.test")
      ]
      outCustomers = @[newCustomer()]

    for inpCustomer in inpCustomers.mitems:
      dbConn.insert inpCustomer

    dbConn.select(outCustomers, """"userId" = ?""", userA.id)

    check outCustomers === inpCustomers[0..^2]
