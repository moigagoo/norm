import std/[unittest, options, times]

import lowdb/postgres

import norm/private/postgres/rowutils
import norm/[model, pragmas]

import ../models


suite "Converting between Model and lowdb.postgres.Row":
  test "Built-in types":
    type
      Person = ref object of Model
        name: string
        age: int
        married: Option[bool]
        initDt: DateTime

    let dt = now().utc

    proc newPerson(name: string, age: int, married: Option[bool]): Person =
      Person(name: name, age: age, married: married, initDt: dt)

    let
      person = newPerson("Alice", 23, some true)
      row: Row = @[?"Alice", ?23, ?true, ?dt]
      fRow: Row = @[?"Alice", ?23, ?true, ?dt, ?person.id]

    var mPerson = newPerson(name = "", age = 0, married = none bool)
    mPerson.fromRow(fRow)

    check person.toRow == row
    check mPerson[] == person[]

  test "Read-only fields":
    type
      Person = ref object of Model
        initDt {.ro.}: DateTime

    let dt = now().utc

    proc newPerson(): Person =
      Person(initDt: dt)

    let
      person = newPerson()
      row: Row = @[]
      fRow: Row = @[?dt, ?person.id]

    var mPerson = newPerson()
    mPerson.fromRow(fRow)

    check person.toRow == row
    check person.toRow(force = true) == fRow
    check mPerson[] == person[]

  test "Nested models":
    let
      toy = newToy(123.45)
      pet = newPet("cat", toy)
      person = newPerson("Alice", pet)
      row: Row = @[?"Alice", ?pet.id]
      fRow: Row = @[?"Alice", ?pet.id, ?"cat", ?toy.id, ?123.45, ?toy.id, ?pet.id, ?person.id]

    var mPerson = newPerson()

    mPerson.fromRow(fRow)

    check person.toRow == row
    check mPerson === person
