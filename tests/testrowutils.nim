import unittest
import times, strutils
import norm / rowutils


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
    check user.toRow() == row

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
        parseIt: it.parse("yyyy-MM-dd HH:mm:sszzz", utc())
      .}: DateTime

  let
    datetimeString = "2019-01-30 12:34:56Z"
    datetime = datetimeString.parse("yyyy-MM-dd HH:mm:sszzz", utc())
    user = UserDatetimeAsString(name: "Alice", age: 23, height: 168.2, createdAt: datetime)
    row = @["Alice", "23", "168.2", datetimeString]

  setup:
    var tmpUser = UserDatetimeAsString(createdAt: now())

  test "Object -> row":
    check user.toRow() == row

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
    check user.toRow() == row

  test "Row -> object":
    row.to(tmpUser)
    check tmpUser == user

  test "Object -> row -> object":
    user.toRow().to(tmpUser)
    check tmpUser == user

  test "Row -> object -> row":
    row.to(tmpUser)
    check tmpUser.toRow() == row

suite "Basic bulk object <-> row conversion":
  type
    SimpleUser = object
      name: string
      age: int
      height: float

  let
    users = @[
      SimpleUser(name: "Alice", age: 23, height: 168.2),
      SimpleUser(name: "Bob", age: 34, height: 172.5),
      SimpleUser(name: "Michael", age: 45, height: 180.0)
    ]
    rows = @[
      @["Alice", "23", "168.2"],
      @["Bob", "34", "172.5"],
      @["Michael", "45", "180.0"]
    ]

  test "Objects -> rows":
    check users.toRows() == rows

  test "Rows -> objects":
    check rows.to(SimpleUser) == users

  test "Objects -> rows -> objects":
    check users.toRows().to(SimpleUser) == users

  test "Rows -> objects -> rows":
    check rows.to(SimpleUser).toRows() == rows

suite "Bulk conversion with custom parser and formatter expressions":
  type
    UserDatetimeAsString = object
      name: string
      age: int
      height: float
      createdAt {.
        formatIt: it.format("yyyy-MM-dd HH:mm:sszzz"),
        parseIt: it.parse("yyyy-MM-dd HH:mm:sszzz", utc())
      .}: DateTime

  let
    datetimeString = "2019-01-30 12:34:56Z"
    datetime = datetimeString.parse("yyyy-MM-dd HH:mm:sszzz", utc())
    users = @[
      UserDatetimeAsString(name: "Alice", age: 23, height: 168.2, createdAt: datetime),
      UserDatetimeAsString(name: "Bob", age: 34, height: 172.5, createdAt: datetime),
      UserDatetimeAsString(name: "Michael", age: 45, height: 180.0, createdAt: datetime)
    ]
    rows = @[
      @["Alice", "23", "168.2", datetimeString],
      @["Bob", "34", "172.5", datetimeString],
      @["Michael", "45", "180.0", datetimeString]
    ]

  setup:
    var tmpUsers = @[
      UserDatetimeAsString(createdAt: now()),
      UserDatetimeAsString(createdAt: now()),
      UserDatetimeAsString(createdAt: now())
    ]

  test "Objects -> rows":
    check users.toRows() == rows

  test "Rows -> objects":
    rows.to(tmpUsers)
    check tmpUsers == users

  test "Objects -> rows -> objects":
    users.toRows().to(tmpUsers)
    check tmpUsers == users

  test "Rows -> objects -> rows":
    rows.to(tmpUsers)
    check tmpUsers.toRows() == rows

suite "Bulk conversion with custom parser and formatter procs":
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
    users = @[
      UserDatetimeAsTimestamp(name: "Alice", age: 23, height: 168.2, createdAt: datetime),
      UserDatetimeAsTimestamp(name: "Bob", age: 34, height: 172.5, createdAt: datetime),
      UserDatetimeAsTimestamp(name: "Michael", age: 45, height: 180.0, createdAt: datetime)
    ]
    rows = @[
      @["Alice", "23", "168.2", datetime.toTimestamp],
      @["Bob", "34", "172.5", datetime.toTimestamp],
      @["Michael", "45", "180.0", datetime.toTimestamp]
    ]

  setup:
    var tmpUsers = @[
      UserDatetimeAsTimestamp(createdAt: now()),
      UserDatetimeAsTimestamp(createdAt: now()),
      UserDatetimeAsTimestamp(createdAt: now())
    ]

  test "Objects -> rows":
    check users.toRows() == rows

  test "Rows -> objects, equal lengths":
    rows.to(tmpUsers)
    check tmpUsers == users

  test "Rows -> objects, more rows than objects":
    discard tmpUsers.pop()

    rows.to(tmpUsers)

    for i in 0..1:
      check tmpUsers[i] == users[i]

  test "Rows -> objects, more objects than rows":
    var u = UserDatetimeAsTimestamp(createdAt: now())

    tmpUsers.add u

    rows.to(tmpUsers)

    for i in 0..2:
      check tmpUsers[i] == users[i]

    check len(tmpUsers) == len(rows)

  test "Objects -> rows -> objects":
    users.toRows().to(tmpUsers)
    check tmpUsers == users

  test "Rows -> objects -> rows":
    rows.to(tmpUsers)
    check tmpUsers.toRows() == rows

suite "Utils":
  test "Empty row check":
    assert @["", "", ""].isEmpty()
