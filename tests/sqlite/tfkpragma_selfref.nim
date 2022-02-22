import std/[unittest, os, strutils, options]

import norm/[model, sqlite]

import ../models


const dbFile = "test.db"


suite "``fk`` pragma on self referencing":
  setup:
    removeFile dbFile

    let dbConn = open(dbFile, "", "", "")

    dbConn.createTables(newSelfRef())

  teardown:
    close dbConn
    removeFile dbFile

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
    dbConn.select(child, "parent = ?", parentid)
    check child.parent == some(parentid)

    var parent = newSelfRef()
    dbConn.select(parent, "id = ?", child.parent.get())
    check parent.id > 0
    check parent.parent == none(int64)

