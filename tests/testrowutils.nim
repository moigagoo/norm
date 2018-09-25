import unittest
from db_sqlite import Row

import rester / rowutils


suite "test object to row and reverse conversions":
  setup:
    type
      User = object
        email: string
        age: int

      Constant = object
        title: string
        value: float

    let
      userRow: Row = @["bob@example.com", "42"]
      user = User(email: "bob@example.com", age: 42)
      constantRow: Row = @["tau", "6.28"]
      constant = Constant(title: "tau", value: 6.28)

  test "row to object":
    check (userRow.to User) == user
    check (constantRow.to Constant) == constant

  test "object to row":
    check user.toRow() == userRow
    check constant.toRow() == constantRow

  test "row to object to row":
      let
        userFromRow = userRow.to User
        rowFromUser = userFromRow.toRow()

      check rowFromUser == userRow

  test "object to row to object":
    let
      rowFromUser = user.toRow()
      userFromRow = rowFromUser.to User

    check userFromRow == user
