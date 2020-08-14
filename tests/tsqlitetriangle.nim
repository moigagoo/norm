import unittest
import os
import sugar

import norm/[model, sqlite]

import models


const dbFile = "test.db"


suite "Relation triangle":
  setup:
    removeFile dbFile

    let dbConn = open(dbFile, "", "", "")

    dbConn.createTables(newPetPerson())

    var
      toy = newToy(123.45)
      pet = newPet("cat", toy)
      person = newPerson("Alice", pet)
      petPerson = newPetPerson(pet, person)

    dbConn.insert(petPerson)

  teardown:
    close dbConn
    removeFile dbFile

  test "Get row":
    let outPetPerson = newPetPerson().dup:
      dbConn.select(""""PetPerson".id = $1""", petPerson.id)

    check outPetPerson === petPerson
