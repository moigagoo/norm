import unittest
import std/with
import os
import strutils

import norm/[model, sqlite]

import models


const dbFile = "test.db"


suite "Table creation and dropping":
  setup:
    removeFile dbFile
    let dbConn = open(dbFile, "", "", "")

  teardown:
    close dbConn
    removeFile dbFile

  test "Create table":
    let toy = initToy(123.45)

    dbConn.createTables(toy)

    let qry = "PRAGMA table_info($#);"

    check dbConn.getAllRows(sql qry % "Toy") == @[
      @[?0, ?"price", ?"FLOAT", ?1, ?nil, ?0],
      @[?1, ?"id", ?"INTEGER", ?1, ?nil, ?1],
    ]

    dbConn.createTables(toy, force = true)

    check dbConn.getAllRows(sql qry % "Toy") == @[
      @[?0, ?"price", ?"FLOAT", ?1, ?nil, ?0],
      @[?1, ?"id", ?"INTEGER", ?1, ?nil, ?1],
    ]

  test "Create tables":
    let
      toy = initToy(123.45)
      pet = initPet("cat", toy)
      person = initPerson("Alice", pet)

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
      @[?1, ?"pet", ?"INTEGER", ?1, ?nil, ?0],
      @[?2, ?"id", ?"INTEGER", ?1, ?nil, ?1],
    ]

    dbConn.createTables(person, force = true)

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
      @[?1, ?"pet", ?"INTEGER", ?1, ?nil, ?0],
      @[?2, ?"id", ?"INTEGER", ?1, ?nil, ?1],
    ]

  test "Drop table":
    let toy = initToy(123.45)

    with dbConn:
      createTables(toy)
      dropTables(toy)

    expect DbError:
      dbConn.exec sql "SELECT NULL FROM Toy"

  test "Drop tables":
    let
      toy = initToy(123.45)
      pet = initPet("cat", toy)
      person = initPerson("Alice", pet)

    with dbConn:
      createTables(person)
      dropTables(person)

    expect DbError:
      dbConn.exec sql "SELECT NULL FROM Toy"
      dbConn.exec sql "SELECT NULL FROM Pet"
      dbConn.exec sql "SELECT NULL FROM Person"
