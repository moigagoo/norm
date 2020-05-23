import unittest
import std/with
import os
import strutils
import strformat
import sugar
import options
import sequtils

import norm/[model, sqlite]

import models


const dbFile = "test.db"


suite "Chaining":
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
    let toys = @[Toy()].dup:
      dbConn.select(fmt"""{Toy().col("price")} < ?""", 50)
      dbConn.delete
      dbConn.select(fmt"""{Toy().col("price")} > ?""", 50)
      apply(doublePrice)
      dbConn.update

    check collect(newSeq, for toy in toys: toy.price) == @[8 * 8 * 2.0, 9 * 9 * 2.0, 10 * 10 * 2.0]
    check toys == @[Toy()].dup(dbConn.select("1"))

  test "Outplacing":
    var toys = @[Toy()]

    with toys:
      dbConn.select(fmt"""{Toy().col("price")} < ?""", 50)
      dbConn.delete

    check @[Toy()].dup(dbConn.select("1")).len == 3

    with toys:
      dbConn.select(fmt"""{Toy().col("price")} > ?""", 50)
      apply(doublePrice)
      dbConn.update

    check collect(newSeq, for toy in toys: toy.price) == @[8 * 8 * 2.0, 9 * 9 * 2.0, 10 * 10 * 2.0]
    check toys == @[Toy()].dup(dbConn.select("1"))
