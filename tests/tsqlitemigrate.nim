import unittest

import os, options

import norm/sqlite


const dbName = "test.db"


db(dbName, "", "", ""):
  type
    Person {.dbTable: "person"} = object
      name: string
      age: int

    PersonAddColumn {.dbTable: "person".} = object
      name: string
      age: int
      ssn: Option[int]

    PersonRemoveColumn {.dbTable: "person".} = object
      name: string

    PersonRenameColumn {.dbTable: "person".} = object
      name {.dbCol: "fullname".}: string
      years: int

    PersonRenameTable {.dbTable: "personrenamed".} = object
      name: string
      age: int


suite "Migrations":
  removeFile dbName

  setup:
    withDb:
      Person.createTable(force=true)

      transaction:
        for i in 1..9:
          var person = Person(name: "Person $#" % $i, age: 20+i)
          person.insert()

  test "Add column":
    withDb:
      addColumn(PersonAddColumn.ssn)

      check dbConn.getAllRows(sql "PRAGMA table_info(person)") == @[
        @[?0, ?"id", ?"INTEGER", ?1, ?"0", ?1],
        @[?1, ?"name", ?"TEXT", ?1, ?"''", ?0],
        @[?2, ?"age", ?"INTEGER", ?1, ?"0", ?0],
        @[?3, ?"ssn", ?"INTEGER", ?0, ?nil, ?0]
      ]

      check len(PersonAddColumn.getMany(100)) == 9

  test "Drop unused columns":
    withDb:
      PersonRemoveColumn.dropUnusedColumns()

      check dbConn.getAllRows(sql "PRAGMA table_info(person)") == @[
        @[?0, ?"id", ?"INTEGER", ?1, ?"0", ?1],
        @[?1, ?"name", ?"TEXT", ?1, ?"''", ?0]
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
        @[?0, ?"id", ?"INTEGER", ?1, ?"0", ?1],
        @[?1, ?"fullname", ?"TEXT", ?1, ?"''", ?0],
        @[?2, ?"years", ?"INTEGER", ?1, ?"0", ?0],
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
        @[?0, ?"id", ?"INTEGER", ?1, ?"0", ?1],
        @[?1, ?"fullname", ?"TEXT", ?1, ?"''", ?0],
        @[?2, ?"years", ?"INTEGER", ?1, ?"0", ?0],
      ]

  test "Rollback transaction":
    withDb:
      transaction:
        addColumn PersonAddColumn.ssn
        rollback()

      check dbConn.getAllRows(sql "PRAGMA table_info(person)") == @[
        @[?0, ?"id", ?"INTEGER", ?1, ?"0", ?1],
        @[?1, ?"name", ?"TEXT", ?1, ?"''", ?0],
        @[?2, ?"age", ?"INTEGER", ?1, ?"0", ?0]
      ]

    # Workaround for ``expect`` not working.
    try:
      withDb:
        transaction:
          addColumn PersonAddColumn.ssn
          raise newException(IOError, "This should be raised.")
    except IOError:
      check true
    except:
      check false

  teardown:
    withDb:
      dropTables()

  removeFile dbName
