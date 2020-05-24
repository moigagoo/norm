import unittest
import std/with
import os
import strutils
import sugar
import options

import norm/[model, sqlite]

import models


const dbFile = "test.db"


suite "Row CRUD":
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
      insert(inpToy)
      select(outToy, "price = ?", inpToy.price)

    check outToy == inpToy

  test "Get row, no intermediate objects":
    let
      inpToy = Toy(price: 123.45).dup(dbConn.insert)
      outToy = Toy().dup:
        dbConn.select("price = ?", inpToy.price)

    check outToy == inpToy

  test "Get row, nested models":
    var
      inpPerson = initPerson("Alice", initPet("cat", initToy(123.45)))
      outPerson = initPerson("", initPet("", initToy(0.0)))

    with dbConn:
      insert(inpPerson)
      select(outPerson, "Person.name = ?", inpPerson.name)

  test "Get row, nested models, no intermediate objects":
    let
      inpPerson = Person(name: "Alice", pet: Pet(species: "cat", favToy: Toy(price: 123.45))).dup:
        dbConn.insert
      outPerson = Person().dup:
        dbConn.select("Person.name = ?", inpPerson.name)

    check outPerson == inpPerson

  test "Get rows":
    var
      inpToys = @[initToy(123.45), initToy(456.78), initToy(99.99)]
      outToys = @[initToy(0.0)]

    for inpToy in inpToys.mitems:
      dbConn.insert(inpToy)

    dbConn.select(outToys, "price > ?", 100.00)

    check outToys == inpToys[..1]

  test "Get rows, no intermediate objects":
    let
      inpToys = @[
        Toy(price: 123.45).dup(dbConn.insert),
        Toy(price: 456.78).dup(dbConn.insert),
        Toy(price: 99.99).dup(dbConn.insert)
      ]
      outToys = @[Toy()].dup:
        dbConn.select("price > ?", 100.00)

    check outToys == inpToys[..1]

  test "Get rows, nested models":
    var
      inpPersons = @[
        initPerson("Alice", initPet("cat", initToy(123.45))),
        initPerson("Bob", initPet("dog", initToy(456.78))),
        initPerson("Charlie", initPet("frog", initToy(99.99))),
      ]
      outPersons = @[initPerson("", initPet("", initToy(0.0)))]

    for inpPerson in inpPersons.mitems:
      dbConn.insert(inpPerson)

    dbConn.select(outPersons, "Toy.price > ?", 100.00)

    check outPersons == inpPersons[0..^2]

  test "Get rows, nested models, no intermediate objects":
    let
      inpPersons = @[
        Person(name: "Alice", pet: Pet(species: "cat", favToy: Toy(price: 123.45))).dup(dbConn.insert),
        Person(name: "Bob", pet: Pet(species: "dog", favToy: Toy(price: 456.78))).dup(dbConn.insert),
        Person(name: "Charlie", pet: Pet(species: "frog", favToy: Toy(price: 99.99))).dup(dbConn.insert)
      ]
      outPersons = @[Person()].dup:
        dbConn.select("Toy.price > ?", 100.00)

    check outPersons == inpPersons[0..^2]

  test "Update row":
    var toy = initToy(123.45)

    dbConn.insert(toy)

    toy.doublePrice()

    dbConn.update(toy)

    let row = get dbConn.getRow(sql"SELECT price, id FROM Toy WHERE id = ?", toy.id)

    check row == @[?246.9, ?toy.id]

  test "Update rows":
    var person = initPerson("Alice", initPet("cat", initToy(123.45)))

    dbConn.insert(person)

    person.name = "Bob"
    person.pet.species = "dog"
    person.pet.favToy.doublePrice()

    dbConn.update(person)

    let
      personRow = get dbConn.getRow(sql"SELECT name, pet, id FROM Person WHERE id = ?", person.id)
      petRow = get dbConn.getRow(sql"SELECT species, favToy, id FROM Pet WHERE id = ?", person.pet.id)
      toyRow = get dbConn.getRow(sql"SELECT price, id FROM Toy WHERE id = ?", person.pet.favToy.id)

    check personRow == @[?"Bob", ?person.pet.id, ?person.id]
    check petRow == @[?"dog", ?person.pet.favToy.id, ?person.pet.id]
    check toyRow == @[?246.9, ?person.pet.favToy.id]

  test "Delete row":
    var toy = initToy(123.45)

    with dbConn:
      insert(toy)
      delete(toy)

    let rows = dbConn.getAllRows(sql"SELECT price, id FROM Toy")
    check rows.len == 0

  test "Delete rows":
    var person = initPerson("Alice", initPet("cat", initToy(123.45)))

    with dbConn:
      insert(person)
      delete(person)

    let
      personRows = dbConn.getAllRows(sql"SELECT name, pet, id FROM Person")
      petRows = dbConn.getAllRows(sql"SELECT species, favToy, id FROM Pet")
      toyRows = dbConn.getAllRows(sql"SELECT price, id FROM Toy")

    check personRows.len == 0
    check petRows.len == 0
    check toyRows.len == 0