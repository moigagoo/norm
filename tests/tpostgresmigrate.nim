import unittest

import algorithm

import norm/postgres


const
  dbHost = "postgres_1"
  dbUser = "postgres"
  dbPassword = "postgres"
  dbDatabase = "postgres"

db(dbHost, dbUser, dbPassword, dbDatabase):
  type
    Person {.dbTable: "person"} = object
      name: string
      age: int

    PersonAddColumn {.dbTable: "person".} = object
      name: string
      age: int
      ssn: int

    PersonRemoveColumn {.dbTable: "person".} = object
      name: string

    PersonRenameColumn {.dbTable: "person".} = object
      name {.dbCol: "fullname".}: string
      years: int

    PersonRenameTable {.dbTable: "personrenamed".} = object
      name: string
      age: int

proc getCols(table: string): seq[string] =
  let query = sql "SELECT column_name FROM information_schema.columns WHERE table_name = $1 ORDER BY column_name"

  withDb:
    for col in dbConn.getAllRows(query, table):
      result.add $col[0]

proc getTables(): seq[string] =
  let query = sql "SELECT table_name FROM information_schema.tables WHERE table_schema='public' ORDER BY table_name"

  withDb:
    for col in dbConn.getAllRows(query):
      result.add $col[0]


suite "Migrations":
  withDb:
    dropTables()

  setup:
    withDb:
      Person.createTable(force=true)

      transaction:
        for i in 1..9:
          discard insertId Person(name: "Person $#" % $i, age: 20+i)

  test "Add column":
    withDb:
      addColumn(PersonAddColumn.ssn)

      check getCols("person") == sorted @["id", "name", "age", "ssn"]

      check len(PersonAddColumn.getMany(100)) == 9

  test "Drop columns":
    withDb:
      PersonRemoveColumn.dropColumns ["age"]

      check getCols("person") == sorted @["id", "name"]

      check getTables() == sorted @["person"]

      check len(PersonRemoveColumn.getMany(100)) == 9

  test "Drop unused columns":
    withDb:
      PersonRemoveColumn.dropUnusedColumns()

      check getCols("person") == sorted @["id", "name"]

      check getTables() == sorted @["person"]

      check len(PersonRemoveColumn.getMany(100)) == 9

  test "Rename column":
    withDb:
      PersonRenameColumn.name.renameColumnFrom "name"
      PersonRenameColumn.years.renameColumnFrom "age"

      check getCols("person") == sorted @["id", "fullname", "years"]

      check len(PersonRenameColumn.getMany(100)) == 9

  test "Rename table":
    withDb:
      PersonRenameTable.renameTableFrom "person"

      check getTables() == sorted @["personrenamed"]

      check len(PersonRenameTable.getMany(100)) == 9

  test "Transaction":
    withDb:
      transaction:
        PersonRenameColumn.name.renameColumnFrom "name"
        PersonRenameColumn.years.renameColumnFrom "age"

      check getCols("person") == sorted @["id", "fullname", "years"]

  test "Rollback transaction":
    withDb:
      transaction:
        addColumn PersonAddColumn.ssn
        rollback()

      check getCols("person") == sorted @["id", "name", "age"]

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
