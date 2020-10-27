discard """
output: '''
DEBUG CREATE TABLE IF NOT EXISTS "Foo"(a INTEGER NOT NULL, b FLOAT NOT NULL, id INTEGER NOT NULL PRIMARY KEY)
DEBUG CREATE TABLE IF NOT EXISTS "Baz"(value FLOAT NOT NULL, id INTEGER NOT NULL PRIMARY KEY)
DEBUG CREATE TABLE IF NOT EXISTS "Bar"(aaa INTEGER NOT NULL, bbb INTEGER NOT NULL, ccc INTEGER NOT NULL, id INTEGER NOT NULL PRIMARY KEY, FOREIGN KEY (aaa) REFERENCES "Foo"(id), FOREIGN KEY(bbb) REFERENCES "Foo"(id), FOREIGN KEY(ccc) REFERENCES "Baz"(id))
DEBUG INSERT INTO "Foo" (a, b) VALUES(?, ?) <- @[11, 12.36]
DEBUG INSERT INTO "Baz" (value) VALUES(?) <- @[63.33]
DEBUG INSERT INTO "Bar" (aaa, bbb, ccc) VALUES(?, ?, ?) <- @[1, 1, 1]
DEBUG SELECT "Foo".a, "Foo".b, "Foo".id FROM "Foo"  WHERE Foo.a = ? <- [11]
DEBUG SELECT "Bar".aaa, "Bar".bbb, "bbb".a, "bbb".b, "bbb".id, "Bar".ccc, "ccc".value, "ccc".id, "Bar".id FROM "Bar" LEFT JOIN "Foo" AS "bbb" ON "Bar".bbb = "bbb".id LEFT JOIN "Baz" AS "ccc" ON "Bar".ccc = "ccc".id WHERE Bar.aaa = ? <- [1]
'''
"""

import macros
import strutils
import options
import os

import norm/model
import norm/pragmas
import norm/sqlite

import logging
var consoleLog = newConsoleLogger()
addHandler(consoleLog)

const dbName = "tsqlitefkpragma.db"

type
  Foo = ref object of Model
    a : int
    b: float

  Baz = ref object of Model
    value: float64

  Bar = ref object of Model
    aaa {. fk: Foo .}: int
    bbb : Foo
    ccc: Baz

proc newFoo(): Foo=
  Foo(a: 0, b: 0.0)

proc newBaz(v: float64 = 0.11): Baz=
  Baz(value: v)


proc newBar(): Bar=
  Bar(aaa: 0, bbb: newFoo(), ccc: newBaz())


proc createTable()=
  let db = open(dbName, "", "", "")
  db.exec(sql"DROP TABLE IF EXISTS Foo")
  db.exec(sql"DROP TABLE IF EXISTS Bar")
  db.exec(sql"DROP TABLE IF EXISTS Baz")
  db.createTables(newBar())
  db.close()


proc insertMe()=
  let db = open(dbName, "", "", "")
  var foo : Foo = Foo(a: 11, b: 12.36)
  db.insert(foo)
  doAssert foo.id == 1

  var bar : Bar = Bar(aaa: foo.id, bbb: foo, ccc:newBaz(63.33))
  db.insert(bar)
  doAssert bar.id == 1
  db.close()

proc selectMe()=
  let db = open(dbName, "", "", "")
  var foo = newFoo()
  db.select(foo, "Foo.a = ?", 11)
  doAssert foo.id == 1

  var bar = newBar()
  db.select(bar, "Bar.aaa = ?", foo.id)
  doAssert bar.id == 1
  doAssert bar.aaa == foo.id

  doAssert bar.bbb[] == foo[]
  doAssert bar.ccc.value == 63.33
  db.close()

when isMainModule:
  discard tryRemoveFile(dbName)
  createTable()
  insertMe()
  selectMe()
  discard tryRemoveFile(dbName)
