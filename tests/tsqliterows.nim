import unittest
import std/with
import os
import strutils
import strformat

import norm/[model, sqlite]


const dbFile = "test.db"


suite "Row CRUD":
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
    removeFile dbFile

    let dbConn = open(dbFile, "", "", "")

    dbConn.createTables(initPerson("", initPet("", initToy(0.0))))

  teardown:
    close dbConn
    removeFile dbFile

  test "Insert row":
    var toy = initToy(123.45)

    dbConn.insert(toy)

    check toy.id > 0

    let rows = dbConn.getAllRows(sql"SELECT price, id FROM Toy")

    check rows.len == 1
    check rows[0] == @[?123.45, ?toy.id]

  test "Insert rows":
    var person = initPerson("Alice", initPet("cat", initToy(123.45)))

    dbConn.insert(person)

    check person.id > 0
    check person.pet.id > 0
    check person.pet.favToy.id > 0

    let
      personRows = dbConn.getAllRows(sql"SELECT name, pet, id FROM Person")
      petRows = dbConn.getAllRows(sql"SELECT species, favToy, id FROM Pet")
      toyRows = dbConn.getAllRows(sql"SELECT price, id FROM Toy")

    check personRows.len == 1
    check personRows[0] == @[?"Alice", ?person.pet.id, ?person.id]

    check petRows.len == 1
    check petRows[0] == @[?"cat", ?person.pet.favToy.id, ?person.pet.id]

    check toyRows.len == 1
    check toyRows[0] == @[?123.45, ?person.pet.favToy.id]

  test "Get row":
    var
      inpToy = initToy(123.45)
      outToy = initToy(0.0)

    with dbConn:
      insert inpToy
      select(outToy, fmt"""{inpToy.col("price")} = ?""", inpToy.price)

    check outToy == inpToy

  test "Get row, nested models":
    var
      inpPerson = initPerson("Alice", initPet("cat", initToy(123.45)))
      outPerson = initPerson("", initPet("", initToy(0.0)))

    with dbConn:
      insert inpPerson
      select(outPerson, fmt"""{inpPerson.fCol("name")} = ?""", inpPerson.name)

  test "Get rows":
    var
      inpToys = @[initToy(123.45), initToy(456.78), initToy(99.99)]
      outToys = @[initToy(0.0)]

    for inpToy in inpToys.mitems:
      dbConn.insert(inpToy)

    dbConn.select(outToys, fmt"""{inpToys[0].col("price")} > ?""", 100.00)

    check outToys == inpToys[..1]
