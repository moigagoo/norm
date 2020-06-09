import options
import std/with
import sugar
import strutils

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
    snowflake = newPet("cat", some alice)
    fido = newPet("dog", some bob)
    spot = newPet("dog")

    users = [alice, bob]
    pets = [snowflake, fido, spot]

  with dbConn:
    createTables(snowflake)

    insert(users)
    insert(pets)

  spot.owner = some bob
  dbConn.update(spot)

  let
    dogs = @[newPet()].dup:
      dbConn.select("species = ?", "dog")
    bobsPets = @[newPet("", some newUser())].dup:
      dbConn.select("User.name = ?", "Bob")

  echo "Dogs:"
  for _ in dogs:
    echo "\tDog: $#, owner is none: $#" % [$_[], $_.owner.isNone]

  echo "Bob's pets:"
  for _ in bobsPets:
    echo "\tDog: $#, owner: $#" % [$_[], $get(_.owner)[]]

  close dbConn
