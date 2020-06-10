import options
import std/with
import sugar
import strutils

import logging
addHandler newConsoleLogger(fmtStr = "\t")

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

  dbConn.transaction:
    with dbConn:
      createTables(snowflake)

      insert(users)
      insert(pets)

  spot.owner = some bob
  dbConn.update(spot)

  echo "Dogs:"

  let
    dogs = @[newPet()].dup:
      dbConn.select("species = ?", "dog")

  for dog in dogs:
    echo "dog.id = $#, dog.species = $#, dog.owner.isNone = $#" %
      [$dog.id, $dog.species, $dog.owner.isNone]

  echo "Bob's pets:"

  let bobsPets = @[newPet("", some newUser())].dup:
    dbConn.select("User.name = ?", "Bob")

  for pet in bobsPets:
    echo "pet.id = $#, pet.species = $#, pet.owner.name = $#" %
      [$pet.id, $pet.species, $(get pet.owner).name]

  discard @[newPet()].dup:
    dbConn.select("species = ?", "dog")
    dbConn.delete

  echo "Pets after all dogs were deleted:"

  for pet in @[newPet()].dup(dbConn.select("1")):
    echo "$#" % $pet[]

  close dbConn
