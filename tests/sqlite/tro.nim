import std/[unittest, os, strutils, options]

import norm/[model, sqlite]

import ../models


const dbFile = "test.db"


suite "Read-only models, non-mutating procs":
  setup:
    removeFile dbFile

    putEnv(dbHostEnv, dbFile)

    var
      alice = newPerson("Alice", none Pet)
      bob = newPerson("Bob", none Pet)
      spot = newPet("dog", newToy())
      poppy = newPet("cat", newToy())

    withDb:
      db.createTables(newPerson())
      db.createTables(newPet())
      db.insert(alice)
      db.insert(bob)
      db.insert(spot)
      db.insert(poppy)

  teardown:
    delEnv(dbHostEnv)
    removeFile dbFile

  test "Select rows":
    var
      personNames = @[newPersonName()]
      petSpecies = @[newPetSpecies()]

    withDb:
      db.selectAll(personNames)
      db.selectAll(petSpecies)

    assert len(personNames) == 2
    assert personNames[0].name == "Alice"
    assert personNames[1].name == "Bob"

    assert len(petSpecies) == 2
    assert petSpecies[0].species == "dog"
    assert petSpecies[1].species == "cat"

