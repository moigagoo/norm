import strutils
import times
import unittest

import norm/[model, postgres]

import models


const
  dbHost = "postgres"
  dbUser = "postgres"
  dbPassword = "postgres"
  dbDatabase = "postgres"


suite "``fk`` pragma":
  proc resetDb =
    let dbConn = open(dbHost, dbUser, dbPassword, "template1")
    dbConn.exec(sql "DROP DATABASE IF EXISTS $#" % dbDatabase)
    dbConn.exec(sql "CREATE DATABASE $#" % dbDatabase)
    close dbConn

  setup:
    resetDb()
    let dbConn = open(dbHost, dbUser, dbPassword, dbDatabase)

    dbConn.createTables(newUser())
    dbConn.createTables(newCustomer())

  teardown:
    close dbConn
    resetDb()

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
    check userRows[0][1] == ?user.id
    check abs(userRows[0][0].t - user.lastLogin) < initDuration(milliseconds = 1000)

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

    dbConn.select(outCustomers, """"userid" = $1""", userA.id)

    check outCustomers === inpCustomers[0..^2]
