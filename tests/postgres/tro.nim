import std/[os, unittest, strutils, sugar, options]

import norm/[model, postgres]

import ../models


const
  dbHost = getEnv("PGHOST", "postgres")
  dbUser = getEnv("PGUSER", "postgres")
  dbPassword = getEnv("PGPASSWORD", "postgres")
  dbDatabase = getEnv("PGDATABASE", "postgres")


suite "Read-only models, non-mutating procs":
  proc resetDb =
    let dbConn = open(dbHost, dbUser, dbPassword, "template1")
    dbConn.exec(sql "DROP DATABASE IF EXISTS $#" % dbDatabase)
    dbConn.exec(sql "CREATE DATABASE $#" % dbDatabase)
    close dbConn

  setup:
    resetDb()
    let dbConn = open(dbHost, dbUser, dbPassword, dbDatabase)

    var
      alice = newPerson("Alice", none Pet)
      bob = newPerson("Bob", none Pet)
      spot = newPet("dog", newToy())
      poppy = newPet("cat", newToy())

    dbConn.createTables(newPerson())
    dbConn.createTables(newPet())
    dbConn.insert(alice)
    dbConn.insert(bob)
    dbConn.insert(spot)
    dbConn.insert(poppy)

  teardown:
    close dbConn
    resetDb()

  test "Select rows":
    var
      personNames = @[newPersonName()]
      petSpecies = @[newPetSpecies()]

    dbConn.selectAll(personNames)
    dbConn.selectAll(petSpecies)

    assert len(personNames) == 2
    assert personNames[0].name == "Alice"
    assert personNames[1].name == "Bob"

    assert len(petSpecies) == 2
    assert petSpecies[0].species == "dog"
    assert petSpecies[1].species == "cat"

