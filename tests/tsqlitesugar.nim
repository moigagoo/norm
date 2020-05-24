import unittest
import std/with
import os
import strutils
import sugar
import options
import sequtils

import norm/[model, sqlite]

import models


const dbFile = "test.db"


suite "Fancy syntax":
  proc allToys(dbConn: DbConn): seq[Toy] =
    @[Toy()].dup:
      dbConn.select("1")

  proc prices(toys: openArray[Toy]): seq[float] =
    collect(newSeq):
      for toy in toys:
        toy.price

  setup:
    removeFile dbFile

    let dbConn = open(dbFile, "", "", "")

    dbConn.createTables(Toy())

    for i in 1..10:
      let
        toy = initToy(float i*i).dup(dbConn.insert)

  teardown:
    close dbConn
    removeFile dbFile

  test "Chaining":
    discard @[Toy()].dup:
      dbConn.select("price < ?", 50)
      dbConn.delete
      dbConn.select("price > ?", 50)
      apply(doublePrice)
      dbConn.update

    check dbConn.allToys.len == 3
    check dbConn.allToys.prices == @[8 * 8 * 2.0, 9 * 9 * 2.0, 10 * 10 * 2.0]

  test "Outplacing objects":
    var toys = @[initToy(0.0)]

    with toys:
      dbConn.select("price < ?", 50)
      dbConn.delete

    check dbConn.allToys.len == 3

    with toys:
      dbConn.select("price > ?", 50)
      apply(doublePrice)
      dbConn.update

    check toys.prices == @[8 * 8 * 2.0, 9 * 9 * 2.0, 10 * 10 * 2.0]
    check toys == dbConn.allToys

  test "Outplacing DbConn":
    let toys = dbConn.allToys

    var
      cheapToys = @[initToy(0.0)]
      costlyToys = @[initToy(0.0)]

    with dbConn:
      select(cheapToys, "price < ?", 50)
      select(costlyToys, "price > ?", 50)

    check cheapToys == toys[0..6]
    check costlyToys == toys[7..^1]
