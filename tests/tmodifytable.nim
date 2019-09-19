import unittest

import os, options

import norm/sqlite


const dbName = "test.db"


db(dbName, "", "", ""):
  type
    Person {.table: "person"} = object
      name: string
      age: int

    PersonAddColumn {.table: "person".} = object
      name: string
      age: int
      ssn: Option[int]
    TmpAddColumn  = object
      name: string
      age: int
      ssn: Option[int]

    PersonRemoveColumn {.table: "person".} = object
      name: string
    TmpRemoveColumn  = object
      name: string

    PersonRenameColumn {.table: "person".} = object
      fullname: Option[string]
      age: int
    TmpRenameColumn  = object
      fullname: Option[string]
      age: int

    PersonRenameTable {.table: "personrenamed".} = object
      name: string
      age: int
    TmpRenameTable = object
      name: string
      age: int


suite "Modify table":
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

  test "Add column":
    withDb:
      TmpAddColumn.createTable(force=true)
      Person.copyTo TmpAddColumn
      Person.dropTable()
      PersonAddColumn.createTable(force=true)
      TmpAddColumn.copyTo PersonAddColumn
      TmpAddColumn.dropTable()

      check dbConn.getAllRows(sql "PRAGMA table_info(person)") == @[
        @[?0, ?"id", ?"INTEGER", ?1, ?nil, ?1],
        @[?1, ?"name", ?"TEXT", ?1, ?nil, ?0],
        @[?2, ?"age", ?"INTEGER", ?1, ?nil, ?0],
        @[?3, ?"ssn", ?"INTEGER", ?0, ?nil, ?0]
      ]

      check dbConn.getAllRows(sql "SELECT name FROM sqlite_master where type='table'") == @[
        @[?"person"]
      ]

      check len(PersonAddColumn.getMany(100)) == 9

  test "Remove column":
    withDb:
      TmpRemoveColumn.createTable(force=true)
      Person.copyTo TmpRemoveColumn
      Person.dropTable()
      PersonRemoveColumn.createTable(force=true)
      TmpRemoveColumn.copyTo PersonRemoveColumn
      TmpRemoveColumn.dropTable()

      check dbConn.getAllRows(sql "PRAGMA table_info(person)") == @[
        @[?0, ?"id", ?"INTEGER", ?1, ?nil, ?1],
        @[?1, ?"name", ?"TEXT", ?1, ?nil, ?0]
      ]

      check dbConn.getAllRows(sql "SELECT name FROM sqlite_master where type='table'") == @[
        @[?"person"]
      ]

      check len(PersonRemoveColumn.getMany(100)) == 9

  test "Rename column":
    withDb:
      TmpRenameColumn.createTable(force=true)
      Person.copyTo TmpRenameColumn
      Person.name.copyTo TmpRenameColumn.fullname
      Person.dropTable()
      PersonRenameColumn.createTable(force=true)
      TmpRenameColumn.copyTo PersonRenameColumn
      TmpRenameColumn.dropTable()

      check dbConn.getAllRows(sql "PRAGMA table_info(person)") == @[
        @[?0, ?"id", ?"INTEGER", ?1, ?nil, ?1],
        @[?1, ?"fullname", ?"TEXT", ?0, ?nil, ?0],
        @[?2, ?"age", ?"INTEGER", ?1, ?nil, ?0],
      ]

      check dbConn.getAllRows(sql "SELECT name FROM sqlite_master where type='table'") == @[
        @[?"person"]
      ]

      check len(PersonRenameColumn.getMany(100)) == 9

  test "Rename table":
    withDb:
      TmpRenameTable.createTable(force=true)
      Person.copyTo TmpRenameTable
      Person.dropTable()
      PersonRenameTable.createTable(force=true)
      TmpRenameTable.copyTo PersonRenameTable
      TmpRenameTable.dropTable()

      check dbConn.getAllRows(sql "PRAGMA table_info(personrenamed)") == @[
        @[?0, ?"id", ?"INTEGER", ?1, ?nil, ?1],
        @[?1, ?"name", ?"TEXT", ?1, ?nil, ?0],
        @[?2, ?"age", ?"INTEGER", ?1, ?nil, ?0],
      ]

      check dbConn.getAllRows(sql "SELECT name FROM sqlite_master where type='table'") == @[
        @[?"personrenamed"]
      ]

      check len(PersonRenameTable.getMany(100)) == 9

  # test "Migrate table":
  #   withDb:
  #     Tmp.createTable(force=true)
  #     Person.copyTo Tmp

  #     Person.dropTable()

  #     PersonNew.createTable()
  #     Tmp.copyTo PersonNew

  #     Tmp.dropTable()

  #     check dbConn.getAllRows(sql "PRAGMA table_info(person)") == @[
  #       @[?0, ?"id", ?"INTEGER", ?1, ?nil, ?1],
  #       @[?1, ?"name", ?"TEXT", ?1, ?nil, ?0],
  #       @[?2, ?"age", ?"INTEGER", ?1, ?nil, ?0],
  #       @[?3, ?"ssn", ?"INTEGER", ?0, ?nil, ?0]
  #     ]

  #     expect DbError:
  #       dbConn.exec sql "SELECT NULL FROM tmp"

  #   withDb:
  #     let people = PersonNew.getMany 100

  #     check len(people) == 9

  #     check people[3].name == "Person 4"
  #     check people[3].age == 24
  #     check people[3].ssn == none int

  teardown:
    withDb:
      dropTables()

  removeFile dbName
