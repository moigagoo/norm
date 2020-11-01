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
DEBUG SELECT "Bar".foo, "foo".a, "foo".b, "foo".id, "Bar".baz, "baz".value, "baz".id, "Bar".id FROM "Bar" LEFT JOIN "Foo" AS "foo" ON "Bar".foo = "foo".id LEFT JOIN "Baz" AS "baz" ON "Bar".baz = "baz".id WHERE "Bar".id = $1 <- [1]
'''
"""

import strutils
import unittest

import norm/model
import norm/postgres

import logging
var consoleLog = newConsoleLogger()
addHandler(consoleLog)

const
  dbHost = "postgres"
  dbUser = "postgres"
  dbPassword = "postgres"
  dbDatabase = "postgres"

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

  test "Insert & select with FK with Nested Models":
    var
      inputfoo = Foo(a: 11, b: 12.36)
      inputbaz = Baz(value: 36.36)
      inputbar = Bar(foo: inputfoo, baz: inputbaz)

    dbConn.insert(inputbar)
    doAssert inputbar.id == 1
    check inputbar.id == 1

    var bar = newBar()
    dbConn.select(bar, """"Bar".id = $1""", 1)
    doAssert bar.id == 1
    check bar.id == 1

    doAssert bar.foo.a == 11
    doAssert bar.foo.b == 12.36
    doAssert bar.baz.value == 36.36

    check bar.foo.a == 11
    check bar.foo.b == 12.36
    check bar.baz.value == 36.36
