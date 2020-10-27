discard """
action: "compile"
errormsg : "Pragma fk must be used on an integer field. aaa is not an integer."
file: "sqlite.nim"
"""

import strutils
import unittest

import norm/model
import norm/pragmas
import norm/postgres

const
  dbHost = "postgres"
  dbUser = "postgres"
  dbPassword = "postgres"
  dbDatabase = "postgres"

type
  Fooz = object
    s: int

  Foo = ref object of Model
    a : int
    b: float

  Baz = ref object of Model
    value: float64

  Bar = ref object of Model
    # Does not compile : aaa is not an int
    aaa {. fk: Foo .}: float
    bbb : Foo
    ccc: Baz

proc newFoo(): Foo=
  Foo(a: 0, b: 0.0)

proc newBaz(): Baz=
  Baz(value: 36.366)

proc newBar(): Bar=
  Bar(aaa: 0.1, bbb: newFoo(), ccc: newBaz())

suite "FK Pragma: wrong field":
  proc resetDb =
    let dbConn = open(dbHost, dbUser, dbPassword, "template1")
    dbConn.exec(sql "DROP DATABASE IF EXISTS $#" % dbDatabase)
    dbConn.exec(sql "CREATE DATABASE $#" % dbDatabase)
    close dbConn

  setup:
    resetDb()
    let dbConn = open(dbHost, dbUser, dbPassword, dbDatabase)

  teardown:
    close dbConn
    resetDb()

  test "Create bad table":
    # When using testament "testing" is defined
    when defined(testing):
      dbConn.createTables(newBar())
    else:
      skip()
