import std/[unittest, strutils, sugar]

import norm/[model, postgres]

import ../models


const
  dbHost = "postgres"
  dbUser = "postgres"
  dbPassword = "postgres"
  dbDatabase = "postgres"


suite "Relation triangle":
  proc resetDb =
    let dbConn = open(dbHost, dbUser, dbPassword, "template1")
    dbConn.exec(sql "DROP DATABASE IF EXISTS $#" % dbDatabase)
    dbConn.exec(sql "CREATE DATABASE $#" % dbDatabase)
    close dbConn

  setup:
    resetDb()
    let dbConn = open(dbHost, dbUser, dbPassword, dbDatabase)

    dbConn.createTables(newPetPerson())

    var
      toy = newToy(123.45)
      pet = newPet("cat", toy)
      person = newPerson("Alice", pet)
      petPerson = newPetPerson(pet, person)

    dbConn.insert(petPerson)

  teardown:
    close dbConn
    resetDb()

  test "Get row":
    let outPetPerson = newPetPerson().dup:
      dbConn.select(""""PetPerson".id = $1""", petPerson.id)

    check outPetPerson === petPerson
