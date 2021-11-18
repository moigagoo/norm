import std/[unittest, os, strutils]

import norm/sqlite

import ../models


const dbFile = "test.db"


suite "Table creation":
  setup:
    removeFile dbFile
    let dbConn = open(dbFile, "", "", "")

  teardown:
    close dbConn
    removeFile dbFile

  test "Create table":
    let toy = newToy(123.45)

    dbConn.createTables(toy)

    let qry = "PRAGMA table_info($#);"

    check dbConn.getAllRows(sql qry % "Toy") == @[
      @[?0, ?"price", ?"FLOAT", ?1, ?nil, ?0],
      @[?1, ?"id", ?"INTEGER", ?1, ?nil, ?1],
    ]

  test "Create table with custom name":
    let table = newTable()

    dbConn.createTables(table)

    let qry = "PRAGMA table_info($#);"

    check dbConn.getAllRows(sql qry % "FurnitureTable") == @[
      @[?0, ?"legCount", ?"INTEGER", ?1, ?nil, ?0],
      @[?1, ?"id", ?"INTEGER", ?1, ?nil, ?1],
    ]

  test "Create tables":
    let
      toy = newToy(123.45)
      pet = newPet("cat", toy)
      person = newPerson("Alice", pet)

    dbConn.createTables(person)

    let qry = "PRAGMA table_info($#);"

    check dbConn.getAllRows(sql qry % "Toy") == @[
      @[?0, ?"price", ?"FLOAT", ?1, ?nil, ?0],
      @[?1, ?"id", ?"INTEGER", ?1, ?nil, ?1],
    ]

    check dbConn.getAllRows(sql qry % "Pet") == @[
      @[?0, ?"species", ?"TEXT", ?1, ?nil, ?0],
      @[?1, ?"favToy", ?"INTEGER", ?1, ?nil, ?0],
      @[?2, ?"id", ?"INTEGER", ?1, ?nil, ?1],
    ]

    check dbConn.getAllRows(sql qry % "Person") == @[
      @[?0, ?"name", ?"TEXT", ?1, ?nil, ?0],
      @[?1, ?"pet", ?"INTEGER", ?0, ?nil, ?0],
      @[?2, ?"id", ?"INTEGER", ?1, ?nil, ?1],
    ]

