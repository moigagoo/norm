discard """
  action: "reject"
"""

import std/[os, unittest, os, times, strutils]

import norm/[model, pragmas, sqlite]


const
  dbHost = getEnv("PGHOST", "postgres")
  dbUser = getEnv("PGUSER", "postgres")
  dbPassword = getEnv("PGPASSWORD", "postgres")
  dbDatabase = getEnv("PGDATABASE", "postgres")


type
  User* = ref object of Model
    lastLogin*: DateTime

  Customer* = ref object of Model
    userId* {.fk: User.}: float
    email*: string


proc newUser*(): User = User(lastLogin: now())

proc newCustomer*(userId: int, email: string): Customer =
  Customer(userId: userId, email: email)

proc newCustomer*(userId: int): Customer =
  newCustomer(userId, "")

proc newCustomer*(): Customer =
  newCustomer(newUser().id)


suite "``fk`` pragma: non-``SomeInteger`` field":
  proc resetDb =
    let dbConn = open(dbHost, dbUser, dbPassword, "template1")
    dbConn.exec(sql "DROP DATABASE IF EXISTS $#" % dbDatabase)
    dbConn.exec(sql "CREATE DATABASE $#" % dbDatabase)
    close dbConn

  setup:
    resetDb()
    let dbConn = open(dbHost, dbUser, dbPassword, dbDatabase)

  teardown:
    close dbConn
    resetDb()

  test "Create table":
    dbConn.createTables(newUser())
    dbConn.createTables(newCustomer())
