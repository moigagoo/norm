discard """
  action: "reject"
  errormsg: "can't use mutating procs with read-only models"
  file: "model.nim"
"""

import std/[unittest, os, strutils]

import norm/[model, sqlite]

import ../models


const dbFile = "test.db"


suite "Read-only models, mutating procs":
  setup:
    removeFile dbFile

    putEnv(dbHostEnv, dbFile)

    withDb:
      db.createTables(newPet())

  teardown:
    delEnv(dbHostEnv)
    removeFile dbFile

  test "Insert row":
    var petSpecies = PetSpecies(species: "Species")

    withDb:
      db.insert(petSpecies)

