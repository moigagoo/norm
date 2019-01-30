import unittest

import times, strutils

import rester / rowutils


suite "Basic object <-> row conversion":
  type
    SimpleUser = object
      name: string
      age: int
      height: float

  let
    user = SimpleUser(name: "Alice", age: 23, height: 168.2)
    row = @["Alice", "23", "168.2"]

  test "Object -> row":
    check user.toRow == row

  test "Row -> object":
    check row.to(SimpleUser) == user

  test "Object -> row -> object":
    check user.toRow().to(SimpleUser) == user

  test "Row -> object -> row":
    check row.to(SimpleUser).toRow() == row


suite "Conversion with custom parser and formatter expressions":
  type
    UserDatetimeAsString = object
      name: string
      age: int
      height: float
      createdAt {.
        formatIt: it.format("yyyy-MM-dd HH:mm:sszzz"),
        parseIt: it.parse("yyyy-MM-dd HH:mm:sszzz")
      .}: DateTime

  let
    datetimeString = "2019-01-30 12:34:56+04:00"
    datetime = datetimeString.parse("yyyy-MM-dd HH:mm:sszzz")
    user = UserDatetimeAsString(name: "Alice", age: 23, height: 168.2, createdAt: datetime)
    row = @["Alice", "23", "168.2", datetimeString]

  setup:
    var tmpUser = UserDatetimeAsString(createdAt: now())

  test "Object -> row":
    check user.toRow == row

  test "Row -> object":
    row.to(tmpUser)
    check tmpUser == user

  test "Object -> row -> object":
    user.toRow().to(tmpUser)
    check tmpUser == user

  test "Row -> object -> row":
    row.to(tmpUser)
    check tmpUser.toRow() == row

suite "Conversion with custom parser and formatter procs":
  proc toTimestamp(dt: DateTime): string = $dt.toTime().toUnix()

  proc toDatetime(ts: string): DateTime = ts.parseInt().fromUnix().local()

  type
    UserDatetimeAsTimestamp = object
      name: string
      age: int
      height: float
      createdAt {.formatter: toTimestamp, parser: toDatetime.}: DateTime

  let
    datetime = "2019-01-30 12:34:56+04:00".parse("yyyy-MM-dd HH:mm:sszzz")
    user = UserDatetimeAsTimestamp(name: "Alice", age: 23, height: 168.2, createdAt: datetime)
    row = @["Alice", "23", "168.2", datetime.toTimestamp]

  setup:
    var tmpUser = UserDatetimeAsTimestamp(createdAt: now())

  test "Object -> row":
    check user.toRow == row

  test "Row -> object":
    row.to(tmpUser)
    check tmpUser == user

  test "Object -> row -> object":
    user.toRow().to(tmpUser)
    check tmpUser == user

  test "Row -> object -> row":
    row.to(tmpUser)
    check tmpUser.toRow() == row
