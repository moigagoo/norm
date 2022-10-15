import std/locks

import sqlite, postgres


type 
  Conn = sqlite.DbConn | postgres.DbConn
  Pool*[T: Conn] = ref object 
    defaultSize: Natural
    conns: seq[T]
    poolExhaustedPolicy: PoolExhaustedPolicy
    lock: Lock
  PoolExhaustedError* = object of CatchableError
  PoolExhaustedPolicy* = enum
    pepRaise
    pepExtend


func newPool*[T: Conn](defaultSize: Positive, poolExhaustedPolicy = pepRaise): Pool[T] =
  ##[ Create a connection pool of the given size.

  ``poolExhaustedPolicy`` defines how the pool reacts when a connection is requested but the pool has no connection available:

    - ``pepRaise`` (default) means throw ``PoolExhaustedError``
    - ``pepExtend`` means throw “add another connection to the pool.”
  ]##

  result = Pool[T](defaultSize: defaultSize, conns: newSeq[T](defaultSize), poolExhaustedPolicy: poolExhaustedPolicy)

  initLock(result.lock)

  for conn in result.conns.mitems:
    conn =
      when T is sqlite.DbConn:
        sqlite.getDb()
      elif T is postgres.DbConn:
        postgres.getDb()

func defaultSize*(pool: Pool): Natural =
  pool.defaultSize

func size*(pool: Pool): Natural =
  len(pool.conns)

func pop*[T: Conn](pool: var Pool[T]): T =
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
        result =
          when T is sqlite.DbConn:
            sqlite.getDb()
          elif T is postgres.DbConn:
            postgres.getDb()

func add*[T: Conn](pool: var Pool, dbConn: T) =
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

