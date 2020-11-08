discard """
  cmd: "nim c -d:testing -d:normDebug -r $file"
  output: '''
[Suite] FK Pragma: Query
DEBUG CREATE TABLE IF NOT EXISTS "Foo"(a INTEGER NOT NULL, b REAL NOT NULL, id SERIAL PRIMARY KEY)
DEBUG CREATE TABLE IF NOT EXISTS "Bar"(fooId INTEGER NOT NULL UNIQUE, id SERIAL PRIMARY KEY, FOREIGN KEY (fooId) REFERENCES "Foo"(id))
DEBUG INSERT INTO "Foo" (a, b) VALUES($1, $2) <- @[11, 12.36]
DEBUG INSERT INTO "Bar" (fooId) VALUES($1) <- @[1]
DEBUG SELECT "Foo".a, "Foo".b, "Foo".id FROM "Foo"  WHERE "Foo".a = $1 <- [11]
DEBUG SELECT "Bar".fooId, "Bar".id FROM "Bar"  WHERE "Bar".fooId = $1 <- [1]
'''
  exitcode: 0
"""

import strutils
import unittest

import norm/model
import norm/pragmas
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
    a: int
    b: float

  Bar = ref object of Model
    fooId {. fk: Foo, unique .}: int

proc newFoo(): Foo=
  Foo(a: 0, b: 0.0)

proc newBar(): Bar=
  Bar(fooId: 0)


suite "FK Pragma: Query":
  proc resetDb =
    let dbConn = open(dbHost, dbUser, dbPassword, "template1")
    dbConn.exec(sql "DROP DATABASE IF EXISTS $#" % dbDatabase)
    dbConn.exec(sql "CREATE DATABASE $#" % dbDatabase)
    close dbConn

  setup:
    resetDb()
    let dbConn = open(dbHost, dbUser, dbPassword, dbDatabase)
    dbConn.createTables(newFoo())
    dbConn.createTables(newBar())

  teardown:
    close dbConn
    resetDb()

  test "Insert, Select with FK Pragma":
    var inputfoo = Foo(a: 11, b: 12.36)
    dbConn.insert(inputfoo)
    check inputfoo.id == 1

    var inputbar = Bar(fooId: inputfoo.id)
    dbConn.insert(inputbar)
    check inputbar.id == 1

    var foo = newFoo()
    dbConn.select(foo, """"Foo".a = $1""", 11)
    check foo.id == 1

    var bar = newBar()
    dbConn.select(bar, """"Bar".fooId = $1""", foo.id)
    check bar.id == 1
    check bar.fooId == foo.id
