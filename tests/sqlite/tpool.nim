import std/[unittest, os, strutils]

import norm/[sqlite, pool]

import ../models


const dbFile = "test.db"


suite "Connection pool":
  setup:
    removeFile dbFile
    putEnv(dbHostEnv, dbFile)

  teardown:
    delEnv(dbHostEnv)
    removeFile dbFile

  test "Create and close pool":
    var pool = newPool[DbConn](1)

    check pool.defaultSize == 1
    check pool.size == 1

    close pool

    check pool.size == 0

  test "Create and close pool with custom connection provider":
    func myDb: DbConn = open("test2.db", "", "", "")

    var pool = newPool[DbConn](1, myDb)

    check pool.defaultSize == 1
    check pool.size == 1
    check fileExists("test2.db")

    close pool

    check pool.size == 0

    removeFile("test2.db")

  test "Explicit pool connection":
    var pool = newPool[DbConn](1)
    let db = pool.pop()

    db.createTables(newToy())

    let qry = "PRAGMA table_info($#);"

    check db.getAllRows(sql qry % "Toy") == @[
      @[?0, ?"price", ?"FLOAT", ?1, ?nil, ?0],
      @[?1, ?"id", ?"INTEGER", ?1, ?nil, ?1],
    ]

    pool.add(db)
    close pool

  test "Implicit pool connection":
    var pool = newPool[DbConn](1)

    withDb(pool):
      db.createTables(newToy())

      let qry = "PRAGMA table_info($#);"

      check db.getAllRows(sql qry % "Toy") == @[
        @[?0, ?"price", ?"FLOAT", ?1, ?nil, ?0],
        @[?1, ?"id", ?"INTEGER", ?1, ?nil, ?1],
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
          db.select(toy, "price = ?", price)

        sum += toy.price

    createThread(threads[0], getToy, 123.45)
    createThread(threads[1], getToy, 456.78)

    joinThreads(threads)

    check sum == toy1.price + toy2.price

    close pool

  test "Pool exhausted, raise exception":
    var
      pool = newPool[DbConn](1, poolExhaustedPolicy = pepRaise)
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
            db.select(toy, "price = ?", price)
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
      pool = newPool[DbConn](1, poolExhaustedPolicy = pepExtend)
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

          db.select(toy, "price = ?", price)

          while maxActiveConnectionCount < 2:
            sleep 100

    createThread(threads[0], getToy, 123.45)
    createThread(threads[1], getToy, 456.78)

    joinThreads(threads)

    check maxActiveConnectionCount == 2

    reset pool

    check pool.size == pool.defaultSize

    close pool

  test """
    Given 2 models with one entry depending on another and a pool with a custom connection-creation-proc, 
    When the other entry gets deleted with a connection from the pool 
    Then a DBError should occur due to FK checks
  """:
    var pool = newPool[DbConn](1, proc(): DbConn = open(dbFile, "", "", ""))
    var toy = newToy(123.45)
    var cat = newPet("cat", toy)

    withDb(pool):
      db.createTables(toy)
      db.createTables(cat)

      db.insert(toy)
      db.insert(cat)

      expect DBError:
        db.delete(toy)