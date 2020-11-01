discard """
  cmd: "nim c -d:normDebug -r $file"
  output: '''
[Suite] FK Pragma: Query
DEBUG CREATE TABLE IF NOT EXISTS "Foo"(a INTEGER NOT NULL, b FLOAT NOT NULL, id INTEGER NOT NULL PRIMARY KEY)
DEBUG CREATE TABLE IF NOT EXISTS "Bar"(fooId INTEGER NOT NULL, id INTEGER NOT NULL PRIMARY KEY, FOREIGN KEY (fooId) REFERENCES "Foo"(id))
DEBUG INSERT INTO "Foo" (a, b) VALUES(?, ?) <- @[11, 12.36]
DEBUG INSERT INTO "Bar" (fooId) VALUES(?) <- @[1]
DEBUG SELECT "Foo".a, "Foo".b, "Foo".id FROM "Foo"  WHERE "Foo".a = $1 <- [11]
DEBUG SELECT "Bar".fooId, "Bar".id FROM "Bar"  WHERE "Bar".fooId = $1 <- [1]
'''
"""

import os
import unittest

import norm/model
import norm/pragmas
import norm/sqlite

import logging
var consoleLog = newConsoleLogger()
addHandler(consoleLog)

const dbFile = "tsqlitefkpragma.db"

type
  Foo = ref object of Model
    a : int
    b: float

  Bar = ref object of Model
    fooId {. fk: Foo .}: int

proc newFoo(): Foo=
  Foo(a: 0, b: 0.0)

proc newBar(): Bar=
  Bar(fooId: 0)


suite "FK Pragma: Query":
  setup:
    removeFile dbFile
    let dbConn = open(dbFile, "", "", "")
    dbConn.createTables(newFoo())
    dbConn.createTables(newBar())

  teardown:
    close dbConn
    removeFile dbFile

  test "Create, Insert, Select with FK and Nested Models":
    var inputfoo = Foo(a: 11, b: 12.36)
    dbConn.insert(inputfoo)
    doAssert inputfoo.id == 1
    check inputfoo.id == 1

    var inputbar = Bar(fooId: inputfoo.id)
    dbConn.insert(inputbar)
    doAssert inputbar.id == 1
    check inputbar.id == 1

    var foo = newFoo()
    dbConn.select(foo, """"Foo".a = $1""", 11)
    check foo.id == 1

    var bar = newBar()
    dbConn.select(bar, """"Bar".fooId = $1""", foo.id)
    doAssert bar.id == 1
    doAssert bar.fooId == foo.id
    check bar.id == 1
    check bar.fooId == foo.id
