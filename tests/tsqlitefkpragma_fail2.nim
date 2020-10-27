discard """
  action: "compile"
  errormsg: "Pragma fk must reference a Model. Fooz is not a Model."
  file: "sqlite.nim"
"""

import os
import norm/model
import norm/pragmas
import norm/sqlite

const dbName = "tfkfail2.db"

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


when isMainModule:
  discard tryRemoveFile(dbName)
  let db = open(dbName, "", "", "")
  db.exec(sql"DROP TABLE IF EXISTS Foo")
  db.exec(sql"DROP TABLE IF EXISTS Bar")
  db.exec(sql"DROP TABLE IF EXISTS Baz")
  db.createTables(newBar())
