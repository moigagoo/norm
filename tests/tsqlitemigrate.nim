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

    PersonRemoveColumn {.table: "person".} = object
      name: string

    PersonRenameColumn {.table: "person".} = object
      name {.dbCol: "fullname".}: string
      years: int

    PersonRenameTable {.table: "personrenamed".} = object
      name: string
      age: int


suite "Migrations":
  setup:
    withDb:
      Person.createTable(force=true)

      for i in 1..9:
        var person = Person(name: "Person $#" % $i, age: 20+i)
        person.insert()

  test "Add column":
    withDb:
      addColumn(PersonAddColumn.ssn)

      check dbConn.getAllRows(sql "PRAGMA table_info(person)") == @[
        @[?0, ?"id", ?"INTEGER", ?1, ?nil, ?1],
        @[?1, ?"name", ?"TEXT", ?1, ?nil, ?0],
        @[?2, ?"age", ?"INTEGER", ?1, ?nil, ?0],
        @[?3, ?"ssn", ?"INTEGER", ?0, ?nil, ?0]
      ]

      check len(PersonAddColumn.getMany(100)) == 9

  test "Drop unused columns":
    withDb:
      PersonRemoveColumn.dropUnusedColumns()

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
      PersonRenameColumn.name.renameColumnFrom "name"
      PersonRenameColumn.years.renameColumnFrom "age"

      check dbConn.getAllRows(sql "PRAGMA table_info(person)") == @[
        @[?0, ?"id", ?"INTEGER", ?1, ?nil, ?1],
        @[?1, ?"fullname", ?"TEXT", ?1, ?nil, ?0],
        @[?2, ?"years", ?"INTEGER", ?1, ?nil, ?0],
      ]

      check len(PersonRenameColumn.getMany(100)) == 9

  test "Rename table":
    withDb:
      PersonRenameTable.renameTableFrom "person"

      check dbConn.getAllRows(sql "SELECT name FROM sqlite_master where type='table'") == @[
        @[?"personrenamed"]
      ]

      check len(PersonRenameTable.getMany(100)) == 9

  test "Transaction":
    withDb:
      transaction:
        PersonRenameColumn.name.renameColumnFrom "name"
        PersonRenameColumn.years.renameColumnFrom "age"

      check dbConn.getAllRows(sql "PRAGMA table_info(person)") == @[
        @[?0, ?"id", ?"INTEGER", ?1, ?nil, ?1],
        @[?1, ?"fullname", ?"TEXT", ?1, ?nil, ?0],
        @[?2, ?"years", ?"INTEGER", ?1, ?nil, ?0],
      ]

  test "Rollback transaction":
    withDb:
      transaction:
        addColumn PersonAddColumn.ssn
        rollback()

      check dbConn.getAllRows(sql "PRAGMA table_info(person)") == @[
        @[?0, ?"id", ?"INTEGER", ?1, ?nil, ?1],
        @[?1, ?"name", ?"TEXT", ?1, ?nil, ?0],
        @[?2, ?"age", ?"INTEGER", ?1, ?nil, ?0]
      ]

    expect IOError:
      withDb:
        transaction:
          addColumn PersonAddColumn.ssn
          raise newException(IOError, "This should be raised.")

  teardown:
    withDb:
      dropTables()

  removeFile dbName
