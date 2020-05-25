import unittest
import strutils
import sequtils
import sugar

import norm/[model, postgres]

import models


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
    let toy = initToy(123.45)

    dbConn.createTables(toy)

    let qry = sql """SELECT column_name, data_type, is_nullable
      FROM information_schema.columns
      WHERE table_name = $1
      ORDER BY column_name"""

    let colSpecs = collect(newSeq, for row in dbConn.getAllRows(qry, "Toy"): row.mapIt($it)) == @[
      @["id", "integer", "NO"],
      @["price", "real", "NO"]
    ]

  test "Create tables":
    let
      toy = initToy(123.45)
      pet = initPet("cat", toy)
      person = initPerson("Alice", pet)

    dbConn.createTables(person)

    check true

    let qry = sql """SELECT column_name, data_type
      FROM information_schema.columns
      WHERE table_name = $1
      ORDER BY column_name"""

    check collect(newSeq, for row in dbConn.getAllRows(qry, "Toy"): row.mapIt($it)) == @[
      @["id", "integer"],
      @["price", "real"]
    ]

    check collect(newSeq, for row in dbConn.getAllRows(qry, "Pet"): row.mapIt($it)) == @[
      @["favtoy", "integer"],
      @["id", "integer"],
      @["species", "text"]
    ]

    check collect(newSeq, for row in dbConn.getAllRows(qry, "Person"): row.mapIt($it)) == @[
      @["id", "integer"],
      @["name", "text"],
      @["pet", "integer"]
    ]
