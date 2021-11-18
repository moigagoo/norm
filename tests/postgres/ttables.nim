import std/[unittest, strutils]

import norm/postgres

import ../models


const
  dbHost = "postgres"
  dbUser = "postgres"
  dbPassword = "postgres"
  dbDatabase = "postgres"


suite "Table creation":
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
    let toy = newToy(123.45)

    dbConn.createTables(toy)

    let qry = sql """SELECT column_name::text, data_type::text
      FROM information_schema.columns
      WHERE table_name = $1
      ORDER BY column_name"""

    check dbConn.getAllRows(qry, "Toy") == @[
      @[?"id", ?"bigint"],
      @[?"price", ?"double precision"]
    ]

  test "Create table with custom name":
    let table = newTable()

    dbConn.createTables(table)

    let
      qry = sql """SELECT column_name::text, data_type::text
        FROM information_schema.columns
        WHERE table_name = $1
        ORDER BY column_name"""
      dftDbInt = if high(int) == high(int64): "bigint" else: "integer"

    check dbConn.getAllRows(qry, "FurnitureTable") == @[
      @[?"id", ?"bigint"],
      @[?"legcount", ?dftDbInt]
    ]

  test "Create tables":
    let
      toy = newToy(123.45)
      pet = newPet("cat", toy)
      person = newPerson("Alice", pet)

    dbConn.createTables(person)

    check true

    let qry = sql """SELECT column_name::text, data_type::text
      FROM information_schema.columns
      WHERE table_name = $1
      ORDER BY column_name"""

    check dbConn.getAllRows(qry, "Toy") == @[
      @[?"id", ?"bigint"],
      @[?"price", ?"double precision"]
    ]

    check dbConn.getAllRows(qry, "Pet") == @[
      @[?"favtoy", ?"bigint"],
      @[?"id", ?"bigint"],
      @[?"species", ?"text"]
    ]

    check dbConn.getAllRows(qry, "Person") == @[
      @[?"id", ?"bigint"],
      @[?"name", ?"text"],
      @[?"pet", ?"bigint"]
    ]

