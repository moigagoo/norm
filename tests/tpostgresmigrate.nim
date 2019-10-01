import unittest

import norm/postgres


const
  dbHost = "postgres_1"
  dbUser = "postgres"
  dbPassword = ""
  dbDatabase = "postgres"

db(dbHost, dbUser, dbPassword, dbDatabase):
  type
    Person {.table: "person"} = object
      name: string
      age: int

    PersonAddColumn {.table: "person".} = object
      name: string
      age: int
      ssn {.default: "0".}: int

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
      dropTables()

      Person.createTable(force=true)

      for i in 1..9:
        var person = Person(name: "Person $#" % $i, age: 20+i)
        person.insert()

  test "Add column":
    withDb:
      addColumn(PersonAddColumn.ssn)

      let getColsQuery = sql "SELECT column_name FROM information_schema.columns WHERE table_name = ?"

      check dbConn.getAllRows(getColsQuery, "person") == @[@["id"], @["name"], @["age"], @["ssn"]]

      check len(PersonAddColumn.getMany(100)) == 9

  test "Remove column":
    withDb:
      updateColumns(PersonRemoveColumn)

      let
        getColsQuery = sql "SELECT column_name FROM information_schema.columns WHERE table_name = ?"
        getTablesQuery = sql "SELECT table_name FROM information_schema.tables WHERE table_schema='public'"

      check dbConn.getAllRows(getColsQuery, "person") == @[@["id"], @["name"]]

      check dbConn.getAllRows(getTablesQuery) == @[@["person"]]

      check len(PersonRemoveColumn.getMany(100)) == 9

  test "Rename column":
    withDb:
      PersonRenameColumn.name.renameColumnFrom "name"
      PersonRenameColumn.years.renameColumnFrom "age"

      let getColsQuery = sql "SELECT column_name FROM information_schema.columns WHERE table_name = ?"

      check dbConn.getAllRows(getColsQuery, "person") == @[@["id"], @["fullname"], @["years"]]

      check len(PersonRenameColumn.getMany(100)) == 9

  test "Rename table":
    withDb:
      PersonRenameTable.renameTableFrom "person"

      let getTablesQuery = sql "SELECT table_name FROM information_schema.tables WHERE table_schema='public'"

      check dbConn.getAllRows(getTablesQuery) == @[@["personrenamed"]]

      check len(PersonRenameTable.getMany(100)) == 9

  teardown:
    withDb:
      dropTables()
