import unittest

import os, options

import norm/sqlite


const dbName = "test.db"


db(dbName, "", "", ""):
  type
    Person = object
      name: string
      age: int

    Tmp = object
      name: string
      age: int
      ssn: Option[int]

    PersonNew {.table: "person".} = object
      name: string
      age: int
      ssn: Option[int]

suite "Migration":
  setup:
    withDb:
      Person.createTable(force=true)

      for i in 1..9:
        var person = Person(name: "Person $#" % $i, age: 20+i)
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
      Person.copyTo Tmp

      Person.dropTable()

      PersonNew.createTable()
      Tmp.copyTo PersonNew

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
      let people = PersonNew.getMany 100

      check len(people) == 9

      check people[3].name == "Person 4"
      check people[3].age == 24
      check people[3].ssn == none int

  teardown:
    withDb:
      dropTables()

  removeFile dbName
