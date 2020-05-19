import unittest
import std/with
import os
import strutils

import norm/[model, sqlite]


const dbFile = "test.db"


suite "Table creation and dropping":
  type
    Toy = object of Model
      price: float

    Pet = object of Model
      species: string
      favToy: Toy

    Person = object of Model
      name: string
      pet: Pet

  func initToy(price: float): Toy = Toy(price: price)

  func initPet(species: string, favToy: Toy): Pet =
    Pet(species: species, favToy: favToy)

  func initPerson(name: string, pet: Pet): Person =
    Person(name: name, pet: pet)

  setup:
    let dbConn = open(dbFile, "", "", "")

  teardown:
    close dbConn
    removeFile dbFile

  test "Create table":
    let toy = initToy(123.45)

    with dbConn:
      createTable(toy)

    let qry = "PRAGMA table_info($#);"

    check dbConn.getAllRows(sql qry % "Toy") == @[
      @[?0, ?"price", ?"FLOAT", ?1, ?nil, ?0],
      @[?1, ?"id", ?"INTEGER", ?1, ?nil, ?1],
    ]

    with dbConn:
      createTable(toy, force = true)

    check dbConn.getAllRows(sql qry % "Toy") == @[
      @[?0, ?"price", ?"FLOAT", ?1, ?nil, ?0],
      @[?1, ?"id", ?"INTEGER", ?1, ?nil, ?1],
    ]

  test "Create tables":
    let
      toy = initToy(123.45)
      pet = initPet("cat", toy)
      person = initPerson("Alice", pet)

    with dbConn:
      createTables(person)

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

    with dbConn:
      createTables(person, force = true)

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
      createTable(toy)
      dropTable(toy)

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
