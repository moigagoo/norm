import std/[unittest, os, options, strutils]

import norm/[model, sqlite]

import ../models


const dbFile = "test.db"


suite "Indexes":
  setup:
    removeFile dbFile

    let dbConn = open(dbFile, "", "", "")

    dbConn.createTables(newStudent())

  teardown:
    close dbConn
    removeFile dbFile

  test "Create indexes":
    let qry = "PRAGMA index_list($#);"

    check dbConn.getAllRows(sql qry % "Student") == @[
      @[?0, ?"idx_student_emails", ?0, ?"c", ?0],
      @[?1, ?"idx_student_names", ?0, ?"c", ?0]
    ]
 
