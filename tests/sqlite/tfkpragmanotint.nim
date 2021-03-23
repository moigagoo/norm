discard """
  action: "reject"
"""

import std/[unittest, os, times, strutils]

import norm/[model, pragmas, sqlite]


const dbFile = "test.db"


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
  setup:
    removeFile dbFile
    let dbConn = open(dbFile, "", "", "")

  teardown:
    close dbConn
    removeFile dbFile

  test "Create table":
    dbConn.createTables(newUser())
    dbConn.createTables(newCustomer())
