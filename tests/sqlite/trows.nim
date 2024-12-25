import std/[unittest, with, os, sugar, options]

import norm/[model, sqlite]

import ../models

const dbFile = "test.db"

suite "Row CRUD":
  setup:
    removeFile dbFile

    putEnv("DB_HOST", dbFile)
    let dbConn = getDb()

    dbConn.createTables(newPerson())

  teardown:
    close dbConn
    removeFile dbFile

  test "Insert row":
    var toy = newToy(123.45)

    dbConn.insert(toy)

    check toy.id > 0

    let rows = dbConn.getAllRows(sql"SELECT price, id FROM Toy")

    check rows.len == 1
    check rows[0] == @[?123.45, ?toy.id]

  test "Insert row twice":
    var toy = newToy(123.45)

    dbConn.insert(toy)
    dbConn.insert(toy, force = true, conflictPolicy = cpReplace)

    check toy.id == 1

    let rows = dbConn.getAllRows(sql"SELECT price, id FROM Toy")

    check rows.len == 1
    check rows[^1] == @[?123.45, ?toy.id]

  test "Insert with forced id":
    var toy = newToy(137.45)
    toy.id = 134
    dbConn.insert(toy, force = true)
    check toy.id == 134

  test "Insert row with forced id in non-incremental order":
    block:
      var toy = newToy(123.45)
      toy.id = 3
      dbConn.insert(toy, force=true)
      check toy.id == 3
    block:
      var toy = newToy(123.45)
      toy.id = 2
      dbConn.insert(toy, force=true)
      check toy.id == 2
    block:
      # Check no id conflict
      var toy = newToy(123.45)
      dbConn.insert(toy)
      # SQLite ids starts from the highest ?
      check toy.id == 4
    block:
      # Check no id conflict
      var toy = newToy(123.45)
      dbConn.insert(toy)
      # SQLite ids starts from the highest ?
      check toy.id == 5

  test "Insert rows":
    var person = newPerson("Alice", newPet("cat", newToy(123.45)))
    dbConn.insert(person)

    let pet = get person.pet

    check person.id > 0
    check pet.id > 0
    check pet.favToy.id > 0

    let
      personRows = dbConn.getAllRows(sql"SELECT name, pet, id FROM Person")
      petRows = dbConn.getAllRows(sql"SELECT species, favToy, id FROM Pet")
      toyRows = dbConn.getAllRows(sql"SELECT price, id FROM Toy")

    check personRows.len == 1
    check personRows[0] == @[?"Alice", ?pet.id, ?person.id]

    check petRows.len == 1
    check petRows[0] == @[?"cat", ?pet.favToy.id, ?pet.id]

    check toyRows.len == 1
    check toyRows[0] == @[?123.45, ?pet.favToy.id]

  test "Get row":
    var
      inpToy = newToy(123.45)
      outToy = newToy()

    with dbConn:
      insert(inpToy)
      select(outToy, "price = ?", inpToy.price)

    check outToy === inpToy

  test "Get row, record not found":
    var outToy = newToy()

    expect KeyError:
      with dbConn:
        select(outToy, "Toy.id = ?", 1)

    expect NotFoundError:
      with dbConn:
        select(outToy, "Toy.id = ?", 1)

  test "Get row, no intermediate objects":
    let
      inpToy = newToy(123.45).dup(dbConn.insert)
      outToy = newToy().dup:
        dbConn.select("price = ?", inpToy.price)

    check outToy === inpToy

  test "Get row, nested models":
    var
      inpPerson = newPerson("Alice", newPet("cat", newToy(123.45)))
      outPerson = newPerson()

    with dbConn:
      insert(inpPerson)
      select(outPerson, "Person.name = ?", inpPerson.name)

  test "Get row, nested models, no intermediate objects":
    let
      inpPerson = newPerson("Alice", some newPet("cat", newToy(123.45))).dup:
        dbConn.insert
      outPerson = newPerson().dup:
        dbConn.select("Person.name = ?", inpPerson.name)

    check outPerson === inpPerson

  test "Get rows":
    var
      inpToys = @[newToy(123.45), newToy(456.78), newToy(99.99)]
      outToys = @[newToy()]

    for inpToy in inpToys.mitems:
      dbConn.insert(inpToy)

    dbConn.select(outToys, "price > ?", 100.00)

    check outToys === inpToys[0..1]

  test "Get all rows":
    var
      inpToys = @[newToy(123.45), newToy(456.78), newToy(99.99)]
      outToys = @[newToy()]

    dbConn.insert(inpToys)

    dbConn.selectAll(outToys)

    check outToys === inpToys

  test "Get all rows, implicit object instantiation":
    var inpToys = @[newToy(123.45), newToy(456.78), newToy(99.99)]

    dbConn.insert(inpToys)

    let outToys = dbConn.selectAll(Toy)

    check outToys === inpToys

  test "Get rows, no intermediate objects":
    let
      inpToys = @[
        Toy(price: 123.45).dup(dbConn.insert),
        Toy(price: 456.78).dup(dbConn.insert),
        Toy(price: 99.99).dup(dbConn.insert)
      ]
      outToys = @[newToy()].dup:
        dbConn.select("price > ?", 100.00)

    check outToys === inpToys[0..1]

  test "Get rows, implicit object instantiation":
    var
      inpToys = @[newToy(123.45), newToy(456.78), newToy(99.99)]

    dbConn.insert(inpToys)

    let outToys = dbConn.select(Toy, "price > ?", 100.00)

    check outToys === inpToys[0..1]

  test "Get rows, nested models":
    var
      inpPersons = @[
        newPerson("Alice", newPet("cat", newToy(123.45))),
        newPerson("Bob", newPet("dog", newToy(456.78))),
        newPerson("Charlie", newPet("frog", newToy(99.99))),
      ]
      outPersons = @[newPerson()]

    for inpPerson in inpPersons.mitems:
      dbConn.insert(inpPerson)

    dbConn.select(outPersons, "pet_favToy.price > ?", 100.00)

    check outPersons === inpPersons[0..^2]

  test "Get rows, nested models, no intermediate objects":
    let
      inpPersons = @[
        newPerson("Alice", newPet("cat", newToy(123.45))).dup(dbConn.insert),
        newPerson("Bob", newPet("dog", newToy(456.78))).dup(dbConn.insert),
        newPerson("Charlie", newPet("frog", newToy(99.99))).dup(dbConn.insert)
      ]
      outPersons = @[newPerson()].dup:
        dbConn.select("pet_favToy.price > ?", 100.00)

    check outPersons === inpPersons[0..^2]

  test "Update row":
    var toy = newToy(123.45)

    dbConn.insert(toy)

    toy.doublePrice()

    dbConn.update(toy)

    let row = get dbConn.getRow(sql"SELECT price, id FROM Toy WHERE id = ?", toy.id)

    check row == @[?246.9, ?toy.id]

  test "Update rows":
    var
      person = newPerson("Alice", newPet("cat", newToy(123.45)))
      pet = get person.pet

    dbConn.insert(person)

    person.name = "Bob"
    pet.species = "dog"
    pet.favToy.doublePrice()

    dbConn.update(person)

    let
      personRow = get dbConn.getRow(sql"SELECT name, pet, id FROM Person WHERE id = ?", person.id)
      petRow = get dbConn.getRow(sql"SELECT species, favToy, id FROM Pet WHERE id = ?", pet.id)
      toyRow = get dbConn.getRow(sql"SELECT price, id FROM Toy WHERE id = ?", pet.favToy.id)

    check personRow == @[?"Bob", ?pet.id, ?person.id]
    check petRow == @[?"dog", ?pet.favToy.id, ?pet.id]
    check toyRow == @[?246.9, ?pet.favToy.id]

  test "Delete row":
    var person = newPerson("Alice", some newPet("cat", newToy(123.45)))

    dbConn.insert(person)
    dbConn.delete(person)

    check dbConn.getRow(sql"SELECT * FROM Person WHERE name = 'Alice'").isNone

  test "Delete rows cascade":
    var
      cat = newPet("cat", newToy(123.45))
      person = newPerson("Alice", some cat)

    dbConn.insert(person)
    dbConn.delete(cat)

    check dbConn.getRow(sql"SELECT * FROM Person WHERE name = 'Alice'").isNone

  test """
    Given 2 models with one entry depending on another, 
    When the other entry gets deleted 
    Then a DBError should occur due to FK checks
  """:
    var toy = newToy(123.45)
    var cat = newPet("cat", toy)

    dbConn.insert(toy)
    dbConn.insert(cat)

    expect DBError:
      dbConn.delete(toy)
