import std/locks

import sqlite, postgres


type
  Pool*[T: sqlite.DbConn | postgres.DbConn] = ref object
    defaultSize: Natural
    conns: seq[T]
    getDbProc: proc: T
    poolExhaustedPolicy: PoolExhaustedPolicy
    lock: Lock
  PoolExhaustedError* = object of CatchableError
  PoolExhaustedPolicy* = enum
    pepRaise
    pepExtend

proc newPool*[T: sqlite.DbConn](defaultSize: Natural, getDbProc: proc(): sqlite.DbConn {.closure.} = sqlite.getDb, poolExhaustedPolicy = pepRaise): Pool[T] =
  ##[ Create an SQLite connection pool of the given size.

  ``poolExhaustedPolicy`` defines how the pool reacts when a connection is requested but the pool has no connection available:

    - ``pepRaise`` (default) means throw ``PoolExhaustedError``
    - ``pepExtend`` means “add another connection to the pool.”
  ]##

  let dbProc = proc(): sqlite.DbConn =
    result = getDbProc()
    result.exec(sql"PRAGMA foreign_keys=on;")

  result = Pool[T](defaultSize: defaultSize, conns: newSeq[T](defaultSize), getDbProc: dbProc, poolExhaustedPolicy: poolExhaustedPolicy)

  initLock(result.lock)

  for conn in result.conns.mitems:
    conn = result.getDbProc()

proc newPool*[T: postgres.DbConn](defaultSize: Natural, getDbProc = postgres.getDb, poolExhaustedPolicy = pepRaise): Pool[T] =
  ##[ Create a Postgres connection pool of the given size.

  ``poolExhaustedPolicy`` defines how the pool reacts when a connection is requested but the pool has no connection available:

    - ``pepRaise`` (default) means throw ``PoolExhaustedError``
    - ``pepExtend`` means “add another connection to the pool.”
  ]##

  let dbProc = getDbProc

  result = Pool[T](defaultSize: defaultSize, conns: newSeq[T](defaultSize), getDbProc: dbProc, poolExhaustedPolicy: poolExhaustedPolicy)

  initLock(result.lock)

  for conn in result.conns.mitems:
    conn = result.getDbProc()

func defaultSize*(pool: Pool): Natural =
  pool.defaultSize

func size*(pool: Pool): Natural =
  len(pool.conns)

proc pop*[T: sqlite.DbConn | postgres.DbConn](pool: var Pool[T]): T =
  ##[ Take a connection from the pool.

  If you're calling this manually, don't forget to `add <#add,Pool,DbConn>`_ it back!
  ]##

  withLock(pool.lock):
    if pool.size > 0:
      result = pool.conns.pop()
    else:
      case pool.poolExhaustedPolicy
      of pepRaise:
        raise newException(PoolExhaustedError, "Pool exhausted")
      of pepExtend:
        result = pool.getDbProc()

func add*[T: sqlite.DbConn | postgres.DbConn](pool: var Pool, dbConn: T) =
  ##[ Add a connection to the pool.

  Use to return a borrowed connection to the pool.
  ]##

  withLock(pool.lock):
    pool.conns.add(dbConn)

func reset*(pool: var Pool) =
  ## Reset pool size to ``defaultSize`` by closing and removing extra connections.

  withLock(pool.lock):
    while pool.size > pool.defaultSize:
      var conn = pool.conns.pop()
      close conn

func close*(pool: var Pool) =
  ## Close the pool by closing and removing all its connetions.

  withLock(pool.lock):
    for conn in pool.conns.mitems:
      close conn

    pool.conns.setLen(0)

template withDb*(pool: var Pool, body: untyped): untyped =
  ##[ Wrapper for DB operations.

  Takes a ``DbConn`` from a pool as ``db`` variable,
  runs your code in a ``try`` block, and returns connection to the pool afterward.
  ]##

  block:
    let db {.inject.} = pool.pop()

    try:
      body

    finally:
      pool.add(db)

