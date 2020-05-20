import unittest

import norm/model


suite "Getting table and columns from ``norm.Model``":
  test "Table":
    type
      Person = object of Model

    let person = Person()

    check Person.table == "'Person'"
    check person.table == "'Person'"

  test "Columns":
    type
      Toy = object of Model
        price: float

      Pet = object of Model
        species: string
        favToy: Toy

      Person = object of Model
        name: string
        pet: Pet

    func initToy(price: float): Toy = Toy(price: price)

    func initPet(species: string, favToy: Toy): Pet =
      Pet(species: species, favToy: favToy)

    func initPerson(name: string, pet: Pet): Person =
      Person(name: name, pet: pet)

    let
      toy = initToy(123.45)
      pet = initPet("cat", toy)
      person = initPerson("Alice", pet)

    check person.col("name") == "name"
    check person.pet.col("species") == "species"

    check person.cols == @["name", "pet"]
    check person.cols(force = true) == @["name", "pet", "id"]

    check person.fCol("name") == "'Person'.name"
    check person.pet.fCol("species") == "'Pet'.species"

    check person.rfCols == @["'Person'.name", "'Pet'.species", "'Toy'.price", "'Toy'.id", "'Pet'.id", "'Person'.id"]
    check toy.rfCols == @["'Toy'.price", "'Toy'.id"]

  test "Join groups":
    type
      Toy = object of Model
        price: float

      Pet = object of Model
        species: string
        favToy: Toy

      Person = object of Model
        name: string
        pet: Pet

    func initToy(price: float): Toy = Toy(price: price)

    func initPet(species: string, favToy: Toy): Pet =
      Pet(species: species, favToy: favToy)

    func initPerson(name: string, pet: Pet): Person =
      Person(name: name, pet: pet)

    let
      toy = initToy(123.45)
      pet = initPet("cat", toy)
      person = initPerson("Alice", pet)

    check person.joinGroups == @[("'Pet'", "'Person'.pet", "'Pet'.id"), ("'Toy'", "'Pet'.favToy", "'Toy'.id")]
