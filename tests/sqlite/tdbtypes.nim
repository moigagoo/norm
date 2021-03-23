import std/[unittest, os, strutils, times, sugar, with]

import norm/[model, sqlite, types]

import ../models


const dbFile = "test.db"


suite "Import dbTypes from norm/private/sqlite/dbtypes":
  setup:
    removeFile dbFile

    let dbConn = open(dbFile, "", "", "")

    dbConn.createTables(newUser())
    dbConn.createTables(newNumber())
    dbConn.createTables(newString())

  teardown:
    close dbConn
    removeFile dbFile

  test "dbValue[DateTime] is imported":
    let users = @[newUser()].dup:
      dbConn.select("""lastLogin <= ?""", ?now())

    check len(users) == 0

  test "Flavors of ``int``, create table":
    let qry = "PRAGMA table_info($#);"

    check dbConn.getAllRows(sql qry % "Number") == @[
      @[?0, ?"n", ?"INTEGER", ?1, ?nil, ?0],
      @[?1, ?"n16", ?"INTEGER", ?1, ?nil, ?0],
      @[?2, ?"n32", ?"INTEGER", ?1, ?nil, ?0],
      @[?3, ?"n64", ?"INTEGER", ?1, ?nil, ?0],
      @[?4, ?"id", ?"INTEGER", ?1, ?nil, ?1]
    ]

  test "Flavors of ``int``, insert row":
    var number = newNumber(1, 2'i16, 3'i32, 4'i64)

    dbConn.insert(number)

    check number.id > 0

    let rows = dbConn.getAllRows(sql"""SELECT n, n16, n32, n64, id FROM "Number"""")

    check rows.len == 1
    check rows[0] == @[?1, ?2'i16, ?3'i32, ?4'i64, ?number.id]

  test "Flavors of ``int``, get row":
    var
      inpNumber = newNumber(1, 2'i16, 3'i32, 4'i64)
      outNumber = newNumber()

    with dbConn:
      insert(inpNumber)
      select(outNumber, "n = $1", 1)

    check inpNumber === outNumber

  test "Flavors of ``string``, create table":
    let qry = "PRAGMA table_info($#);"

    check dbConn.getAllRows(sql qry % "String") == @[
      @[?0, ?"s", ?"TEXT", ?1, ?nil, ?0],
      @[?1, ?"sc10", ?"TEXT", ?1, ?nil, ?0],
      @[?2, ?"psc5", ?"TEXT", ?1, ?nil, ?0],
      @[?3, ?"id", ?"INTEGER", ?1, ?nil, ?1]
    ]

  test "Flavors of ``string``, insert row":
    var str = newString("foo", newStringOfCap[10]("bar"), newPaddedStringOfCap[5]("baz"))

    dbConn.insert(str)

    check str.id > 0

    let rows = dbConn.getAllRows(sql"""SELECT s, sc10, psc5, id FROM "String"""")

    check rows.len == 1

    check rows[0][0] == ?"foo"
    check rows[0][1] == ?"bar"
    check rows[0][2] == ?"baz  "
    check rows[0][3] == ?str.id

  test "Flavors of ``string``, get row":
    var
      inpString = newString("foo", newStringOfCap[10]("bar"), newPaddedStringOfCap[5]("baz"))
      outString = newString()

    with dbConn:
      insert(inpString)
      select(outString, "s = $1", "foo")

    check inpString === outString
