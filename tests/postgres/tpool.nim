import std/[unittest, os, strutils]

import norm/[postgres, pool]

import ../models


const
  dbHost = "postgres"
  dbUser = "postgres"
  dbPassword = "postgres"
  dbDatabase = "postgres"


suite "Connection pool":
  proc resetDb =
    let dbConn = open(dbHost, dbUser, dbPassword, "template1")
    dbConn.exec(sql "DROP DATABASE IF EXISTS $#" % dbDatabase)
    dbConn.exec(sql "CREATE DATABASE $#" % dbDatabase)
    close dbConn

  setup:
    resetDb()

    putEnv(dbHostEnv, dbHost)
    putEnv(dbUserEnv, dbUser)
    putEnv(dbPassEnv, dbPassword)
    putEnv(dbNameEnv, dbDatabase)

  teardown:
    delEnv(dbHostEnv)
    delEnv(dbUserEnv)
    delEnv(dbPassEnv)
    delEnv(dbNameEnv)

    resetDb()

  test "Create and close pool":
    var pool = newPool[DbConn](1)

    check pool.defaultSize == 1
    check pool.size == 1

    close pool

    check pool.size == 0

  test "Explicit pool connection":
    var pool = newPool[DbConn](1)
    let db = pool.pop()

    db.createTables(newToy())

    let qry = sql """SELECT column_name::text, data_type::text
      FROM information_schema.columns
      WHERE table_name = $1
      ORDER BY column_name"""

    check db.getAllRows(qry, "Toy") == @[
      @[?"id", ?"bigint"],
      @[?"price", ?"double precision"]
    ]

    pool.add(db)
    close pool

  test "Implicit pool connection":
    var pool = newPool[DbConn](1)

    withDb(pool):
      db.createTables(newToy())

      let qry = sql """SELECT column_name::text, data_type::text
        FROM information_schema.columns
        WHERE table_name = $1
        ORDER BY column_name"""

      check db.getAllRows(qry, "Toy") == @[
        @[?"id", ?"bigint"],
        @[?"price", ?"double precision"]
      ]

    close pool

  test "Concurrent pool connections":
    var
      pool = newPool[DbConn](2)
      toy1 = newToy(123.45)
      toy2 = newToy(456.78)
      threads: array[2, Thread[float]]
      sum: float

    withDb(pool):
      db.createTables(toy1)
      db.insert(toy1)
      db.insert(toy2)

    proc getToy(price: float) {.thread.} =
      {.cast(gcsafe).}:
        var toy = newToy()

        withDb(pool):
          db.select(toy, "price = $1", price)

        sum += toy.price

    createThread(threads[0], getToy, 123.45)
    createThread(threads[1], getToy, 456.78)

    joinThreads(threads)

    check sum == toy1.price + toy2.price

    close pool

  test "Pool exhausted, raise exception":
    var
      pool = newPool[DbConn](1, pepRaise)
      toy1 = newToy(123.45)
      toy2 = newToy(456.78)
      threads: array[2, Thread[float]]
      exceptionRaised: bool

    withDb(pool):
      db.createTables(toy1)
      db.insert(toy1)
      db.insert(toy2)

    proc getToy(price: float) {.thread.} =
      {.cast(gcsafe).}:
        var toy = newToy()

        try:
          withDb(pool):
            db.select(toy, "price = $1", price)
            while not exceptionRaised:
              sleep 100
        except PoolExhaustedError:
          exceptionRaised = true 

    createThread(threads[0], getToy, 123.45)
    createThread(threads[1], getToy, 456.78)

    joinThreads(threads)

    check exceptionRaised

    close pool

  test "Pool exhausted, extend and reset pool":
    var
      pool = newPool[DbConn](1, pepExtend)
      toy1 = newToy(123.45)
      toy2 = newToy(456.78)
      threads: array[2, Thread[float]]
      maxActiveConnectionCount: Natural

    withDb(pool):
      db.createTables(toy1)
      db.insert(toy1)
      db.insert(toy2)

    proc getToy(price: float) {.thread.} =
      {.cast(gcsafe).}:
        var toy = newToy()

        withDb(pool):
          inc maxActiveConnectionCount

          db.select(toy, "price = $1", price)

          while maxActiveConnectionCount < 2:
            sleep 100

    createThread(threads[0], getToy, 123.45)
    createThread(threads[1], getToy, 456.78)

    joinThreads(threads)

    check maxActiveConnectionCount == 2

    reset pool

    check pool.size == pool.defaultSize

    close pool

