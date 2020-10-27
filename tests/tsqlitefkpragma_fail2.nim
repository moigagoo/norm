discard """
action: "compile"
errormsg: "Pragma fk must reference a Model. Fooz is not a Model."
file: "sqlite.nim"
"""

import os
import unittest

import norm/model
import norm/pragmas
import norm/sqlite

const dbFile = "tfkfail2.db"

type
  Fooz = object
    s: int

  Foo = ref object of Model
    a : int
    b: float

  Baz = ref object of Model
    value: float64

  Bar = ref object of Model
    # Does not compile : Fooz is not a Model
    aaa {. fk: Fooz .}: int
    bbb : Foo
    ccc: Baz

proc newFoo(): Foo=
  Foo(a: 0, b: 0.0)

proc newBaz(): Baz=
  Baz(value: 36.366)

proc newBar(): Bar=
  Bar(aaa: 0, bbb: newFoo(), ccc: newBaz())


suite "FK Pragma: not Model":
  setup:
    removeFile dbFile

    let dbConn = open(dbFile, "", "", "")

  teardown:
    close dbConn
    removeFile dbFile

  test "Create bad table":
    dbConn.createTables(newBar())
