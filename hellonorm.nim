import options
import std/with
import sugar

import logging; addHandler newConsoleLogger(fmtStr = "")

import norm/[model, sqlite]


type
  User = ref object of Model
    name: string
    age: Natural

  Pet = ref object of Model
    species: string
    owner: Option[User]


func newUser(name = "", age = 0): User = User(name: name, age: age)

func newPet(species = "", owner = none User): Pet = Pet(species: species, owner: owner)


when isMainModule:
  let dbConn = open(":memory:", "", "", "")

  var
    alice = newUser("Alice", 23)
    bob = newUser("Bob", 45)
    snowflake = newPet("cat")
    fido = newPet("dog")
    spot = newPet("dog")

  with dbConn:
    createTables(alice)
    createTables(snowflake)

  close dbConn
