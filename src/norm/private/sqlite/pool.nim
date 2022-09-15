import ../log
import ../genericPool
import ndb/sqlite
import std/os

export PoolDefect
export dbHostEnv
export withDb

var SQLITE_POOL {.global.}: ConnectionPool[DbConn] = nil


# Sugar to get DB config from environment variables

proc getDb*(): DbConn =
  ## Create a ``DbConn`` from ``DB_HOST`` environment variable.
  open(getEnv(dbHostEnv), "", "", "")

proc dropDb* =
  ## Remove the DB file defined in environment variable.
  #TODO: Figure out if this proc should exist, and if so, if the "template1" is actually needed. If this must look like this, it might be necessary to set env when starting things up just to make sure that you can grab things via env variables
  removeFile(getEnv(dbHostEnv))


# Handling DB connections

proc borrowConnection*(): DbConn {.gcsafe.} =
  {.cast(gcsafe).}:
    SQLITE_POOL.borrowConnection()

proc recycleConnection*(connection: var DbConn) {.gcsafe.} =
  {.cast(gcsafe).}:
    SQLITE_POOL.recycleConnection(move connection)

proc initConnectionPool*(
  createConnectionProc: CreateConnectionProc[DbConn] = getDb,
  poolSize: int = 4,
  burstModeDuration: Duration = initDuration(minutes = 30)
) =
  SQLITE_POOL.initConnectionPool(createConnectionProc, poolSize, burstModeDuration)

proc initConnectionPool*(
  databasePath: string = ":memory:",
  poolSize: int = 4,
  burstModeDuration: Duration = initDuration(minutes = 30)
) =
  let createConnectionProc: CreateConnectionProc[DbConn] = proc(): DbConn = open(databasePath, "", "", "")
  initConnectionPool(createConnectionProc, poolSize, burstModeDuration)

proc destroyConnectionPool*() =
  SQLITE_POOL.destroyConnectionPool()