import unittest

import os, options

import norm/sqlite

import migrations/person


const dbName = "test.db"


dbTypes:
  type
    Tmp = object
      name*: string
      age*: int
      ssn*: Option[int]

dbFromTypes(dbName, "", "", "",
            [Person1568833072, Person1569092269, Tmp])


suite "Migration, models defined in a separate module":
  setup:
    withDb:
      Person1568833072.createTable(force=true)

      for i in 1..9:
        var person = Person1568833072(name: "Person $#" % $i, age: 20+i)
        person.insert()

  test "Create table":
    withDb:
      check dbConn.getAllRows(sql "PRAGMA table_info(person)") == @[
        @[?0, ?"id", ?"INTEGER", ?1, ?nil, ?1],
        @[?1, ?"name", ?"TEXT", ?1, ?nil, ?0],
        @[?2, ?"age", ?"INTEGER", ?1, ?nil, ?0]
      ]

  test "Migrate table":
    withDb:
      Tmp.createTable(force=true)
      Person1568833072.copyTo Tmp

      Person1568833072.dropTable()

      Person1569092269.createTable()
      Tmp.copyTo Person1569092269

      Tmp.dropTable()

      check dbConn.getAllRows(sql "PRAGMA table_info(person)") == @[
        @[?0, ?"id", ?"INTEGER", ?1, ?nil, ?1],
        @[?1, ?"name", ?"TEXT", ?1, ?nil, ?0],
        @[?2, ?"age", ?"INTEGER", ?1, ?nil, ?0],
        @[?3, ?"ssn", ?"INTEGER", ?0, ?nil, ?0]
      ]

      expect DbError:
        dbConn.exec sql "SELECT NULL FROM tmp"

    withDb:
      let people = Person1569092269.getMany 100

      check len(people) == 9

      check people[3].name == "Person 4"
      check people[3].age == 24
      check people[3].ssn == none int

  teardown:
    withDb:
      dropTables()

  removeFile dbName
