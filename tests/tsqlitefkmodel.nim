discard """
  cmd: "nim c -d:normDebug -r $file"
  output: '''

[Suite] Foreign Key: Nested Model
DEBUG CREATE TABLE IF NOT EXISTS "Foo"(a INTEGER NOT NULL, b FLOAT NOT NULL, id INTEGER NOT NULL PRIMARY KEY)
DEBUG CREATE TABLE IF NOT EXISTS "Baz"(value FLOAT NOT NULL, id INTEGER NOT NULL PRIMARY KEY)
DEBUG CREATE TABLE IF NOT EXISTS "Bar"(foo INTEGER NOT NULL, baz INTEGER NOT NULL, id INTEGER NOT NULL PRIMARY KEY, FOREIGN KEY(foo) REFERENCES "Foo"(id), FOREIGN KEY(baz) REFERENCES "Baz"(id))
DEBUG INSERT INTO "Foo" (a, b) VALUES(?, ?) <- @[11, 12.36]
DEBUG INSERT INTO "Baz" (value) VALUES(?) <- @[36.36]
DEBUG INSERT INTO "Bar" (foo, baz) VALUES(?, ?) <- @[1, 1]
DEBUG SELECT "Bar".foo, "foo".a, "foo".b, "foo".id, "Bar".baz, "baz".value, "baz".id, "Bar".id FROM "Bar" LEFT JOIN "Foo" AS "foo" ON "Bar".foo = "foo".id LEFT JOIN "Baz" AS "baz" ON "Bar".baz = "baz".id WHERE Bar.id = ? <- [1]
'''
"""

import os
import unittest

import norm/model
import norm/sqlite

import logging
var consoleLog = newConsoleLogger()
addHandler(consoleLog)

const dbFile = "tsqlitefkmodel.db"

type
  Foo = ref object of Model
    a : int
    b: float

  Baz = ref object of Model
    value: float64

  Bar = ref object of Model
    foo : Foo
    baz : Baz

proc newFoo(): Foo=
  Foo(a: 0, b: 0.0)

proc newBaz(): Baz=
  Baz(value: 0.0)

proc newBar(): Bar=
  Bar(foo: newFoo(), baz: newBaz())

suite "Foreign Key: Nested Model":
  setup:
    removeFile dbFile

    let dbConn = open(dbFile, "", "", "")

  teardown:
    close dbConn
    removeFile dbFile

  test "Create, Insert, Select with FK and Nested Models":
    block: # Create table
      dbConn.createTables(newBar())

    block: # Insert
      var foo : Foo = Foo(a: 11, b: 12.36)
      var baz : Baz = Baz(value: 36.36)
      var bar : Bar = Bar(foo: foo, baz: baz)
      dbConn.insert(bar)
      doAssert bar.id == 1

    block: # select
      var bar = newBar()
      dbConn.select(bar, "Bar.id = ?", 1)
      doAssert bar.id == 1

      doAssert bar.foo.a == 11
      doAssert bar.foo.b == 12.36
      doAssert bar.baz.value == 36.36