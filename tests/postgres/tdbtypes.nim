import unittest
import std/with
import strutils
import times
import json
import sugar

import norm/[model, postgres, types]

import ../models

import logging
addHandler newConsoleLogger()


const
  dbHost = "postgres"
  dbUser = "postgres"
  dbPassword = "postgres"
  dbDatabase = "postgres"


suite "Import dbTypes from norm/private/postgres/dbtypes":
  proc resetDb =
    let dbConn = open(dbHost, dbUser, dbPassword, "template1")
    dbConn.exec(sql "DROP DATABASE IF EXISTS $#" % dbDatabase)
    dbConn.exec(sql "CREATE DATABASE $#" % dbDatabase)
    close dbConn

  setup:
    resetDb()
    let dbConn = open(dbHost, dbUser, dbPassword, dbDatabase)

    # dbConn.createTables(newUser())
    # dbConn.createTables(newNumber())
    # dbConn.createTables(newString())
    dbConn.createTables(newJson())

  teardown:
    close dbConn
    resetDb()

  # test "dbValue[DateTime] is imported":
  #   let users = @[newUser()].dup:
  #     dbConn.select("""lastLogin <= $1""", ?now())

  #   check len(users) == 0

  # test "Flavors of ``int``, create table":
  #   let
  #     qry = sql """SELECT column_name::text, data_type::text
  #       FROM information_schema.columns
  #       WHERE table_name = $1
  #       ORDER BY column_name"""
  #     dftDbInt = if high(int) == high(int64): "bigint" else: "integer"

  #   check dbConn.getAllRows(qry, "Number") == @[
  #     @[?"id", ?"bigint"],
  #     @[?"n", ?dftDbInt],
  #     @[?"n16", ?"smallint"],
  #     @[?"n32", ?"integer"],
  #     @[?"n64", ?"bigint"]
  #   ]

  # test "Flavors of ``int``, insert row":
  #   var number = newNumber(1, 2'i16, 3'i32, 4'i64)

  #   dbConn.insert(number)

  #   check number.id > 0

  #   let rows = dbConn.getAllRows(sql"""SELECT n, n16, n32, n64, id FROM "Number"""")

  #   check rows.len == 1
  #   check rows[0] == @[?1, ?2'i16, ?3'i32, ?4'i64, ?number.id]

  # test "Flavors of ``int``, get row":
  #   var
  #     inpNumber = newNumber(1, 2'i16, 3'i32, 4'i64)
  #     outNumber = newNumber()

  #   with dbConn:
  #     insert(inpNumber)
  #     select(outNumber, "n = $1", 1)

  #   check inpNumber === outNumber

  # test "Flavors of ``string``, create table":
  #   let qry = sql """SELECT column_name::text, data_type::text, character_maximum_length::integer
  #     FROM information_schema.columns
  #     WHERE table_name = $1
  #     ORDER BY column_name"""

  #   check dbConn.getAllRows(qry, "String") == @[
  #     @[?"id", ?"bigint", ?nil],
  #     @[?"psc5", ?"character", ?5],
  #     @[?"s", ?"text", ?nil],
  #     @[?"sc10", ?"character varying", ?10]
  #   ]

  # test "Flavors of ``string``, insert row":
  #   var str = newString("foo", newStringOfCap[10]("bar"), newPaddedStringOfCap[5]("baz"))

  #   dbConn.insert(str)

  #   check str.id > 0

  #   let rows = dbConn.getAllRows(sql"""SELECT s, sc10, psc5, id FROM "String"""")

  #   check rows.len == 1

  #   check rows[0][0] == ?"foo"
  #   check rows[0][1].o.value == "bar"
  #   check rows[0][2].o.value == "baz  "
  #   check rows[0][3] == ?str.id

  # test "Flavors of ``string``, get row":
  #   var
  #     inpString = newString("foo", newStringOfCap[10]("bar"), newPaddedStringOfCap[5]("baz"))
  #     outString = newString()

  #   with dbConn:
  #     insert(inpString)
  #     select(outString, "s = $1", "foo")

  #   check inpString === outString

  # test "Json, create table":
  #   let qry = sql """SELECT column_name::text, data_type::text, character_maximum_length::integer
  #     FROM information_schema.columns
  #     WHERE table_name = $1
  #     ORDER BY column_name"""

  #   check dbConn.getAllRows(qry, "Json") == @[
  #     @[?"id", ?"bigint", ?nil],
  #     @[?"jarr", ?"json", ?nil],
  #     @[?"jint", ?"json", ?nil],
  #     @[?"jobj", ?"json", ?nil],
  #     @[?"jstr", ?"json", ?nil]
  #   ]

  test "Json, insert row":
    var jso = newJson(%"Alice", %32, %* {"Bob": 42}, %* [{"a": 123}, {"b": 456}])

    dbConn.insert(jso)

    check jso.id > 0

    let rows = dbConn.getAllRows(sql"""SELECT jstr, jint, jobj, jarr, id FROM "Json"""")

    check rows.len == 1

    check parseJson(rows[0][0].o.value) == %"Alice"
    check parseJson(rows[0][1].o.value) == %32
    check parseJson(rows[0][2].o.value) == %* {"Bob": 42}
    check parseJson(rows[0][3].o.value) == %* [{"a": 123}, {"b": 456}]
    check rows[0][4] == ?jso.id
