import unittest
import options
import times

import ndb/postgres

import norm/private/postgres/rowutils
import norm/[model, pragmas]

import models


const dtCmpThsld = initDuration(nanoseconds = 1000)


suite "Converting between Model and ndb.postgres.Row":
  test "Built-in types":
    type
      Person = object of Model
        name: string
        age: int
        married: Option[bool]
        initDt: DateTime

    let dt = now().utc

    proc initPerson(name: string, age: int, married: Option[bool]): Person =
      Person(name: name, age: age, married: married, initDt: dt)

    let
      person = initPerson("Alice", 23, some true)
      row: Row = @[?"Alice", ?23, ?true, ?dt]
      fRow: Row = @[?"Alice", ?23, ?true, ?dt, ?person.id]

    var mPerson = initPerson(name = "", age = 0, married = none bool)
    mPerson.fromRow(fRow)

    check person.toRow == row
    check mPerson == person

  test "Read-only fields":
    type
      Person = object of Model
        initDt {.ro.}: DateTime

    let dt = now().utc

    proc initPerson(): Person =
      Person(initDt: dt)

    let
      person = initPerson()
      row: Row = @[]
      fRow: Row = @[?dt, ?person.id]

    var mPerson = initPerson()
    mPerson.fromRow(fRow)

    check person.toRow == row
    check person.toRow(force = true) == fRow
    check mPerson == person

  test "Nested models":
    let
      toy = initToy(123.45)
      pet = initPet("cat", toy)
      person = initPerson("Alice", pet)
      row: Row = @[?"Alice", ?person.pet.id]
      fRow: Row = @[?"Alice", ?"cat", ?123.45, ?person.pet.favToy.id, ?person.pet.id, ?person.id]

    var
      mToy = initToy(0.0)
      mPet = initPet("", mToy)
      mPerson = initPerson("", mPet)
    mPerson.fromRow(fRow)

    check person.toRow == row
    check mPerson == person
