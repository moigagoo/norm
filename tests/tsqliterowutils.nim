discard """
  action: "run"
  exitcode: 0
"""
import unittest
import options
import times

import ndb/sqlite

import norm/private/sqlite/rowutils
import norm/[model, pragmas]

import models


const dtCmpThsld = initDuration(nanoseconds = 1000)


suite "Converting between Model and ndb.sqlite.Row":
  test "Built-in types":
    type
      Person = ref object of Model
        name: string
        age: int
        married: Option[bool]
        initDt: DateTime

    let
      dt = now().utc
      ts = dt.toTime().toUnixFloat()

    proc newPerson(name: string, age: int, married: Option[bool]): Person =
      Person(name: name, age: age, married: married, initDt: dt)

    proc `~=`(p1, p2: Person): bool =
      p1.name == p2.name and
      p1.age == p2.age and
      p1.married == p2.married and
      abs(p1.initDt - p2.initDt) < dtCmpThsld

    let
      person = newPerson("Alice", 23, some true)
      row: Row = @[?"Alice", ?23, ?1, ?ts]
      fRow: Row = @[?"Alice", ?23, ?1, ?ts, ?person.id]

    var mPerson = newPerson(name = "", age = 0, married = none bool)
    mPerson.fromRow(fRow)

    check person.toRow == row
    check mPerson ~= person

  test "Read-only fields":
    type
      Person = ref object of Model
        initDt {.ro.}: DateTime

    let
      dt = now().utc
      ts = dt.toTime().toUnixFloat()

    proc newPerson(): Person =
      Person(initDt: dt)

    proc `~=`(p1, p2: Person): bool =
      abs(p1.initDt - p2.initDt) < dtCmpThsld

    let
      person = newPerson()
      row: Row = @[]
      fRow: Row = @[?ts, ?person.id]

    var mPerson = newPerson()
    mPerson.fromRow(fRow)

    check person.toRow == row
    check person.toRow(force = true) == fRow
    check mPerson ~= person

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
