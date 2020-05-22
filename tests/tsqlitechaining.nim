import unittest
import os
import strutils
import strformat
import sugar
import options
import sequtils

import norm/[model, sqlite]


const dbFile = "test.db"


suite "Chaining":
  type
    Toy = object of Model
      price: float

    Pet = object of Model
      species: string
      favToy: Toy

    Person = object of Model
      name: string
      pet: Pet

  func initToy(price: float): Toy =
    Toy(price: price)

  func initPet(species: string, favToy: Toy): Pet =
    Pet(species: species, favToy: favToy)

  func initPerson(name: string, pet: Pet): Person =
    Person(name: name, pet: pet)

  proc doublePrice(toy: var Toy) =
    toy.price *= 2.0

  proc doublePrice(person: var Person) =
    doublePrice(person.pet.favToy)

  setup:
    removeFile dbFile

    let dbConn = open(dbFile, "", "", "")

    dbConn.createTables(initPerson("", initPet("", initToy(0.0))))

    for i in 1..10:
      let
        toy = initToy(float i*i)
        pet = initPet(fmt"cat-{i}", toy)
        person = initPerson(fmt"Alice-{i}", pet).dup(dbConn.insert)

  teardown:
    close dbConn
    removeFile dbFile

  test "Chaining":
    let toys = @[Toy()].dup:
      dbConn.select(fmt"""{Toy().col("price")} < ?""", 50)
      dbConn.delete
      dbConn.select(fmt"""{Toy().col("price")} > ?""", 50)
      apply(doublePrice)
      dbConn.update

    check collect(newSeq, for toy in toys: toy.price) == @[8 * 8 * 2.0, 9 * 9 * 2.0, 10 * 10 * 2.0]
    check toys == @[Toy()].dup(dbConn.select("1"))

  test "Chaining, nested models":
    let persons = @[Person()].dup:
      dbConn.select(fmt"""{Person().pet.favToy.fCol("price")} < ?""", 50)
      dbConn.delete
      dbConn.select(fmt"""{Person().pet.favToy.fCol("price")} > ?""", 50)
      apply(doublePrice)
      dbConn.update

    check collect(newSeq, for person in persons: person.pet.favToy.price) == @[8 * 8 * 2.0, 9 * 9 * 2.0, 10 * 10 * 2.0]
    check persons == @[Person()].dup(dbConn.select("1"))

    check true