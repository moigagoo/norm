import std/locks

import sqlite


type 
  Pool* = ref object 
    defaultSize: Natural
    conns: seq[DbConn]
    poolExhaustedPolicy: PoolExhaustedPolicy
    lock: Lock
  PoolExhaustedError* = object of CatchableError
  PoolExhaustedPolicy* = enum
    pepRaise
    pepExtend


func newPool*(defaultSize: Positive, poolExhaustedPolicy = pepRaise): Pool =
  result = Pool(defaultSize: defaultSize, conns: newSeq[DbConn](defaultSize), poolExhaustedPolicy: poolExhaustedPolicy)

  initLock(result.lock)

  for conn in result.conns.mitems:
    conn = getDb()

func defaultSize*(pool: Pool): Natural =
  pool.defaultSize

func size*(pool: Pool): Natural =
  len(pool.conns)

func pop*(pool: var Pool): DbConn =
  withLock(pool.lock):
    if pool.size > 0:
      result = pool.conns.pop()
    else:
      case pool.poolExhaustedPolicy
      of pepRaise:
        raise newException(PoolExhaustedError, "Pool exhausted")
      of pepExtend:
        result = getDb()

func add*(pool: var Pool, dbConn: DbConn) =
  withLock(pool.lock):
    pool.conns.add(dbConn)

func reset*(pool: var Pool) =
  withLock(pool.lock):
    while pool.size > pool.defaultSize:
      var conn = pool.conns.pop()
      close conn

func close*(pool: var Pool) =
  withLock(pool.lock):
    for conn in pool.conns.mitems:
      close conn

    pool.conns.setLen(0)

template withDb*(pool: var Pool, body: untyped): untyped =
  block:
    let db {.inject.} = pool.pop()

    try:
      body

    finally:
      pool.add(db)

