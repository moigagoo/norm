import std/[unittest, os, strutils, options]

import norm/[model, sqlite]

import ../models


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

  test "Insert SelfRef":
    var parent = newSelfRef()
    dbConn.insert parent
    check parent.id > 0

    var child = newSelfRef(parent.id)
    dbConn.insert child
    check child.id > 0

  test "Select SelfRef":
    var parentid: int64 = 0
    block:
      var parent = newSelfRef()
      dbConn.insert parent
      var child = newSelfRef(parent.id)
      dbConn.insert child
      parentid = child.parent.get()

    var child = newSelfRef()
    dbConn.select(child, "parent=$1", parentid)
    check child.parent == some(parentid)

    var parent = newSelfRef()
    dbConn.select(parent, "id=$1", child.parent.get())
    check parent.id > 0
    check parent.parent == none(int64)

