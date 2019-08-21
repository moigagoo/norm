import unittest
import times, strutils
import norm / oldrowutils


suite "Basic object <-> row conversion":
  type
    SimpleUser = object
      name: string
      age: Natural
      height: float
      employed: bool

  let
    user = SimpleUser(name: "Alice", age: 23, height: 168.2, employed: true)
    row = @["Alice", "23", "168.2", "t"]

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
      age: Natural
      height: float
      employed: bool
      createdAt {.
        formatIt: $it.format("yyyy-MM-dd HH:mm:sszz"),
        parseIt: it.parse("yyyy-MM-dd HH:mm:sszz")
      .}: DateTime

  let
    datetimeString = "2019-01-30 12:34:56+00"
    datetime = datetimeString.parse("yyyy-MM-dd HH:mm:sszz")
    user = UserDatetimeAsString(
      name: "Alice",
      age: 23,
      height: 168.2,
      employed: false,
      createdAt: datetime
    )
    row = @["Alice", "23", "168.2", "f", datetimeString]

  setup:
    var tmpUser {.used.} = UserDatetimeAsString(createdAt: now())

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

  proc toDatetime(ts: string): DateTime = parseInt(ts).fromUnix().utc()

  type
    UserDatetimeAsTimestamp = object
      name: string
      age: Natural
      height: float
      employed: bool
      createdAt {.formatter: toTimestamp, parser: toDatetime.}: DateTime

  let
    datetime = "2019-01-30 12:34:56+04".parse("yyyy-MM-dd HH:mm:sszz")
    user = UserDatetimeAsTimestamp(
      name: "Alice",
      age: 23,
      height: 168.2,
      employed: true,
      createdAt: datetime
    )
    row = @["Alice", "23", "168.2", "t", $datetime.toTimestamp()]

  setup:
    var tmpUser {.used.} = UserDatetimeAsTimestamp(createdAt: now())

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
      age: Natural
      height: float
      employed: bool

  let
    users = @[
      SimpleUser(name: "Alice", age: 23, height: 168.2, employed: true),
      SimpleUser(name: "Bob", age: 34, height: 172.5, employed: false),
      SimpleUser(name: "Michael", age: 45, height: 180.0, employed: true)
    ]
    rows = @[
      @["Alice", "23", "168.2", "t"],
      @["Bob", "34", "172.5", "f"],
      @["Michael", "45", "180.0", "t"]
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
      age: Natural
      height: float
      employed: bool
      createdAt {.
        formatIt: $it.format("yyyy-MM-dd HH:mm:sszz"),
        parseIt: it.parse("yyyy-MM-dd HH:mm:sszz")
      .}: DateTime

  let
    datetimeString = "2019-01-30 12:34:56+00"
    datetime = datetimeString.parse("yyyy-MM-dd HH:mm:sszz")
    users = @[
      UserDatetimeAsString(
        name: "Alice",
        age: 23,
        height: 168.2,
        employed: true,
        createdAt: datetime
      ),
      UserDatetimeAsString(
        name: "Bob",
        age: 34,
        height: 172.5,
        employed: false,
        createdAt: datetime
      ),
      UserDatetimeAsString(
        name: "Michael",
        age: 45,
        height: 180.0,
        employed: true,
        createdAt: datetime
      )
    ]
    rows = @[
      @["Alice", "23", "168.2", "t", datetimeString],
      @["Bob", "34", "172.5", "f", datetimeString],
      @["Michael", "45", "180.0", "t", datetimeString]
    ]

  setup:
    var tmpUsers {.used.} = @[
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

  proc toDatetime(ts: string): DateTime = parseInt(ts).fromUnix().utc()

  type
    UserDatetimeAsTimestamp = object
      name: string
      age: Natural
      height: float
      employed: bool
      createdAt {.formatter: toTimestamp, parser: toDatetime.}: DateTime

  let
    datetime = "2019-01-30 12:34:56+04".parse("yyyy-MM-dd HH:mm:sszz")
    users = @[
      UserDatetimeAsTimestamp(
        name: "Alice",
        age: 23,
        height: 168.2,
        employed: true,
        createdAt: datetime
      ),
      UserDatetimeAsTimestamp(
        name: "Bob",
        age: 34,
        height: 172.5,
        employed: false,
        createdAt: datetime
      ),
      UserDatetimeAsTimestamp(
        name: "Michael",
        age: 45,
        height: 180.0,
        employed: true,
        createdAt: datetime
      )
    ]
    rows = @[
      @["Alice",  "23", "168.2", "t", datetime.toTimestamp()],
      @["Bob",  "34", "172.5", "f", datetime.toTimestamp()],
      @["Michael",  "45", "180.0", "t", datetime.toTimestamp()]
    ]

  setup:
    var tmpUsers {.used.} = @[
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

suite "Boolean field conversion":
  type
    Car = object
      manufacturer: string
      model: string
      used: bool

  let
    car = Car(
      manufacturer: "Toyota",
      model: "true",
      used: false
    )
    row = @["Toyota", "true", "f"]

  test "Object -> row":
    check car.toRow() == row

  test "Row -> object":
    check row.to(Car) == car

  test "Object -> row -> object":
    check car.toRow().to(Car) == car

  test "Row -> object -> row":
    check row.to(Car).toRow() == row

suite "DateTime field conversion":
  type
    Person = object
      lastLogin: DateTime

  let
    person = Person(
      lastLogin: "2019-08-19 23:32:53+04".parse("yyyy-MM-dd HH:mm:sszz"),
    )
    row = @["2019-08-19 19:32:53+00"]

  setup:
    var tmpPerson {.used.} = Person(lastLogin: now())

  test "Object -> row":
    check person.toRow() == row

  test "Row -> object":
    row.to(tmpPerson)
    check tmpPerson == person

  test "Object -> row -> object":
    person.toRow().to(tmpPerson)
    check tmpPerson == person

  test "Row -> object -> row":
    row.to(tmpPerson)
    check tmpPerson.toRow() == row
