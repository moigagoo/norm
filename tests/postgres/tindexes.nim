import std/[os, unittest, options, strutils]

import norm/[model, postgres]

import ../models


const
  dbHost = getEnv("PGHOST", "postgres")
  dbUser = getEnv("PGUSER", "postgres")
  dbPassword = getEnv("PGPASSWORD", "postgres")
  dbDatabase = getEnv("PGDATABASE", "postgres")


suite "Indexes":
  proc resetDb =
    let dbConn = open(dbHost, dbUser, dbPassword, "template1")
    dbConn.exec(sql "DROP DATABASE IF EXISTS $#" % dbDatabase)
    dbConn.exec(sql "CREATE DATABASE $#" % dbDatabase)
    close dbConn

  setup:
    resetDb()
    let dbConn = open(dbHost, dbUser, dbPassword, dbDatabase)

    dbConn.createTables(newStudent())

  teardown:
    close dbConn
    resetDb()

  test "Create indexes":
    block listIndexes:
      let qry = sql """SELECT indexname::text
        FROM pg_indexes
        WHERE tablename = $1"""

      check dbConn.getAllRows(qry, "Student") == @[
        @[?"Student_pkey"],
        @[?"idx_student_names"],
        @[?"idx_student_emails"]
      ]

    block checkUniqueIndex:
      let
        qry = sql """SELECT indexdef::text
          FROM pg_indexes
          WHERE tablename = $1 and indexname = $2"""
        row = dbConn.getRow(qry, "Student", "idx_student_emails")

      check get(row)[0].s.startsWith "CREATE UNIQUE INDEX"

