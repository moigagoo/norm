import unittest
import times, strutils, sequtils, sugar, db_sqlite

import rester/rowutils

import macros


template somePragma() {.pragma.}

template somePragmaWithValue(val: string) {.pragma.}


suite "Test object to row and row to object conversion":
  setup:
    type
      User = object
        email: string
        age: int

      Constant = object
        title: string
        value: float

      UserWithPragma {.somePragmaWithValue: "someValue".} = object
        email {.somePragma.}: string
        age: int

    proc initUser(email: string, age: int): User = User(email: email, age: age)

    proc initUserWithPragma(email: string, age: int): UserWithPragma =
      UserWithPragma(email: email, age: age)

    let
      userRow: Row = @["bob@example.com", "42"]
      userObj = initUser("bob@example.com", 42)
      constantRow: Row = @["tau", "6.28"]
      constantObj = Constant(title: "tau", value: 6.28)
      userWithPragmaRow: Row = @["alice@example.com", "23"]
      userWithPragmaObj = initUserWithPragma("alice@example.com", 23)

    type
      Holiday = object
        title{.
          parser: (s: string) => s.split().mapIt(capitalizeAscii(it)).join(" "),
          formatter: (s: string) => s.toLowerAscii()
        .}: string
        date {.
          parser: proc(s: string): DateTime = s.parse("yyyy-MM-dd"),
          formatter: (dt: DateTime) => dt.format("yyyy-MM-dd")
        .}: DateTime

    let
      newYearObj = Holiday(title: "New Year", date: initDateTime(1, mJan, 2019, 0, 0, 0, 0))
      newYearRow: Row = @["new year", "2019-01-01"]

  test "Row to object":
    check (userRow.to User) == userObj
    check (constantRow.to Constant) == constantObj
    check (userWithPragmaRow.to UserWithPragma) == userWithPragmaObj

  test "Object to row":
    check userObj.toRow() == userRow
    check constantObj.toRow() == constantRow
    check userWithPragmaObj.toRow() == userWithPragmaRow

  test "Row to object to row":
    let
      userObjFromRow = userRow.to User
      rowFromUserObj = userObjFromRow.toRow()

    check rowFromUserObj == userRow

  test "Object to row to object":
    let
      rowFromUserObj = userObj.toRow()
      userObjFromRow = rowFromUserObj.to User

    check userObjFromRow == userObj

  test "Row to object with custom parser":
    var newYearObjFromRow = Holiday(date: now())
    newYearRow.to(newYearObjFromRow)

    check newYearObjFromRow == newYearObj

  test "Object to row with custom formatter":
    check newYearObj.toRow == newYearRow

  test "Row to object to row with custom parser and formatter":
    var newYearObjFromRow = Holiday(date: now())
    newYearRow.to(newYearObjFromRow)

    let rowFromNewYearObj = newYearObjFromRow.toRow()

    check rowFromNewYearObj == newYearRow

  test "Object to row to object with custom formatter and parser":
    let rowFromNewYearObj = newYearObj.toRow()

    var newYearObjFromRow = Holiday(date: now())
    rowFromNewYearObj.to(newYearObjFromRow)

    check newYearObjFromRow == newYearObj
