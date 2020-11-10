import unittest

import norm/model

import ../models


suite "Getting table and columns from Model":
  test "Table":
    check Person.table == """"Person""""

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
