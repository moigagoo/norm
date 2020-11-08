discard """
  action: "run"
  exitcode: 0
"""
import unittest
import std/with
import strutils
import sugar
import sequtils

import norm/[model, postgres]

import models


const
  dbHost = "postgres"
  dbUser = "postgres"
  dbPassword = "postgres"
  dbDatabase = "postgres"


suite "Fancy syntax":
  proc resetDb =
    let dbConn = open(dbHost, dbUser, dbPassword, "template1")
    dbConn.exec(sql "DROP DATABASE IF EXISTS $#" % dbDatabase)
    dbConn.exec(sql "CREATE DATABASE $#" % dbDatabase)
    close dbConn

  proc allToys(dbConn: DbConn): seq[Toy] =
    @[newToy()].dup:
      dbConn.select("TRUE")

  proc prices(toys: openArray[Toy]): seq[float] =
    collect(newSeq):
      for toy in toys:
        toy.price

  setup:
    resetDb()
    let dbConn = open(dbHost, dbUser, dbPassword, dbDatabase)

    dbConn.createTables(newToy())

    for i in 1..10:
      let
        toy = newToy(float i*i).dup(dbConn.insert)

  teardown:
    close dbConn
    resetDb()

  test "Chaining":
    discard @[newToy()].dup:
      dbConn.select("price < $1", 50)
      dbConn.delete
    discard @[newToy()].dup:
      dbConn.select("price > $1", 50)
      apply(doublePrice)
      dbConn.update

    check dbConn.allToys.len == 3
    check dbConn.allToys.prices == @[8 * 8 * 2.0, 9 * 9 * 2.0, 10 * 10 * 2.0]

  test "Outplacing objects":
    var toys = @[newToy()]

    with toys:
      dbConn.select("price < $1", 50)
      dbConn.delete

    check dbConn.allToys.len == 3

    toys = @[newToy()]

    with toys:
      dbConn.select("price > $1", 50)
      apply(doublePrice)
      dbConn.update

    check toys.prices == @[8 * 8 * 2.0, 9 * 9 * 2.0, 10 * 10 * 2.0]
    check toys === dbConn.allToys

  test "Outplacing DbConn":
    let toys = dbConn.allToys

    var
      cheapToys = @[newToy(0.0)]
      costlyToys = @[newToy(0.0)]

    with dbConn:
      select(cheapToys, "price < $1", 50)
      select(costlyToys, "price > $1", 50)

    check cheapToys === toys[0..6]
    check costlyToys === toys[7..^1]
