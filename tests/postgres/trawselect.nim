import std/[unittest, with, os, sugar, options, logging, strutils]

import norm/[model, postgres]

import ../models


const
  dbHost = "postgres"
  dbUser = "postgres"
  dbPassword = "postgres"
  dbDatabase = "postgres"

proc resetDb =
  let dbConn = open(dbHost, dbUser, dbPassword, "template1")
  dbConn.exec(sql "DROP DATABASE IF EXISTS $#" % dbDatabase)
  dbConn.exec(sql "CREATE DATABASE $#" % dbDatabase)
  close dbConn


addHandler(newConsoleLogger(levelThreshold = lvlDebug))

suite "Testing rawSelect proc":
  setup:
    resetDb()
    let dbConn = open(dbHost, dbUser, dbPassword, dbDatabase)

    var
      alice = newPerson("Alice", none Pet)
      bob = newPerson("Bob", none Pet)
      jeff = newPerson("Jeff", none Pet)

      someDoctor = newDoctor("Vet1")

      visit1 = newDoctorVisit(alice, someDoctor)
      visit2 = newDoctorVisit(bob, someDoctor)

      boneToy = newToy()
      ballToy = newToy()

      spot = newPlayfulPet("spot", boneToy, ballToy)

    dbConn.createTables(newPerson())
    dbConn.createTables(newDoctor())
    dbConn.createTables(newDoctorVisit())
    dbConn.createTables(newToy())
    dbConn.createTables(newPlayfulPet())
    discard @[alice, bob, jeff].dup:
      dbConn.insert

    discard @[someDoctor].dup:
      dbConn.insert

    discard @[visit1, visit2].dup:
      dbConn.insert

    discard @[boneToy, ballToy].dup:
      dbConn.insert

    discard @[spot].dup:
      dbConn.insert


  teardown:
    close dbConn
    resetDb()


  test "rawSelect single entry":
    type MyDoc = ref object
      name: string

    let sql = """SELECT name FROM "Doctor" WHERE id = $1"""
    var mydoc = MyDoc()
    dbConn.rawSelect(sql, mydoc, someDoctor.id)

    check mydoc.name == "Vet1"

  test "rawSelect multiple entries":
    type MyPerson = ref object
      name: string

    let sql = """SELECT name FROM "Person" ORDER BY id"""
    var myPeople = @[MyPerson()]
    dbConn.rawSelect(sql, myPeople)

    check myPeople.len() == 3
    check myPeople[0].name == "Alice"
    check myPeople[1].name == "Bob"
    check myPeople[2].name == "Jeff"

  test "rawSelect with Model":
    let sql = """SELECT name, NULL, NULL, NULL, NULL, NULL, NULL, id FROM "Person""""
    var myPeople = @[newPerson()]
    dbConn.rawSelect(sql, myPeople)

    check myPeople.len() == 3
    check myPeople[0].name == "Alice"
    check myPeople[0].pet.isNone()
    check myPeople[0].id == 1

    check myPeople[1].name == "Bob"
    check myPeople[1].pet.isNone()
    check myPeople[1].id == 2

    check myPeople[2].name == "Jeff"
    check myPeople[2].pet.isNone()
    check myPeople[2].id == 3