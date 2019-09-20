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
      Person.name.renameTo "fullname"

      check dbConn.getAllRows(sql "PRAGMA table_info(person)") == @[
        @[?0, ?"id", ?"INTEGER", ?1, ?nil, ?1],
        @[?1, ?"fullname", ?"TEXT", ?1, ?nil, ?0],
        @[?2, ?"age", ?"INTEGER", ?1, ?nil, ?0],
      ]

  test "Rename table":
    withDb:
      Person.renameTo "personrenamed"

      check dbConn.getAllRows(sql "SELECT name FROM sqlite_master where type='table'") == @[
        @[?"personrenamed"]
      ]

      check len(PersonRenameTable.getMany(100)) == 9

  teardown:
    withDb:
      dropTables()

  removeFile dbName
