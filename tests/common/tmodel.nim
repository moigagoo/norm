import std/[unittest, options]

import norm/model

import ../models


suite "Getting table and columns from Model":
  test "Table":
    check Person.table == """"Person""""
    check Table.table == """"FurnitureTable""""

  test "Columns":
    let
      toy = newToy(123.45)
      pet = newPet("cat", toy)
      person = newPerson("Alice", pet)

    check person.col("name") == "name"
    check pet.col("species") == "species"

    check person.cols == @["name", "pet"]
    check person.cols(force = true) == @["name", "pet", "id"]

    check person.fCol("name") == """"Person".name"""
    check pet.fCol("species") == """"Pet".species"""

    check person.rfCols == @[
      """"Person".name""",
      """"Person".pet""",
      """"pet".species""",
      """"pet".favToy""",
      """"pet_favToy".price""",
      """"pet_favToy".id""",
      """"pet".id""",
      """"Person".id"""
    ]
    check toy.rfCols == @[""""Toy".price""", """"Toy".id"""]

  test "Join groups":
    let
      toy = newToy(123.45)
      pet = newPet("cat", toy)
      person = newPerson("Alice", pet)

    check person.joinGroups == @[
      (""""Pet"""", """"pet"""", """"Person".pet""", """"pet".id"""),
      (""""Toy"""", """"pet_favToy"""", """"pet".favToy""", """"pet_favToy".id""")
    ]

  test "When related model has field with the type of the given model, expect name of that field as a string":
    check Toy.getRelatedFieldNameOn(Pet) == "favToy"
  
  test "When related model has Optional field with the type of the given model, expect name of that field as a string":
    check Pet.getRelatedFieldNameOn(Person) == "pet"

  test "When related model has field with fk pragma pointing to the given model, expect name of that field as a string":
    check User.getRelatedFieldNameOn(Customer) == "userId"

  test "When related model as Optional field with fk pragma pointing to the given model, expect name of that field as a string":
    check Toy.getRelatedFieldNameOn(UnplayfulPet) == "favToyId"

  test "When related model does not have FK-field pointing to the given model, expect FieldDefect Exception":
    expect FieldDefect:
      discard Pet.getRelatedFieldNameOn(Toy)

