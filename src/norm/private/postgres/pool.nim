import ../genericPool
import ../log
import ndb/postgres
import std/[strutils, os]

export PoolDefect
export dbHostEnv
export dbUserEnv
export dbPassEnv
export dbNameEnv
export withDb

var POSTGRES_POOL {.global.}: ConnectionPool[DbConn] = nil




# Sugar to get DB config from environment variables

proc getDb*(): DbConn =
  ## Create a ``DbConn`` from ``DB_HOST``, ``DB_USER``, ``DB_PASS``, and ``DB_NAME`` environment variables.
  open(getEnv(dbHostEnv), getEnv(dbUserEnv), getEnv(dbPassEnv), getEnv(dbNameEnv))


# DB manipulation

proc dropDb* =
  ## Drop the database defined in environment variables.
  #TODO: Figure out if this proc should exist, and if so, if the "template1" is actually needed. If this must look like this, it might be necessary to set env when starting things up just to make sure that you can grab things via env variables
  let dbConn = open(getEnv(dbHostEnv), getEnv(dbUserEnv), getEnv(dbPassEnv), "template1")
  dbConn.exec(sql "DROP DATABASE IF EXISTS $#" % getEnv(dbNameEnv))
  close dbConn



proc borrowConnection*(): DbConn {.gcsafe.} =
  {.cast(gcsafe).}:
    POSTGRES_POOL.borrowConnection()

proc recycleConnection*(connection: var DbConn) {.gcsafe.} =
  {.cast(gcsafe).}:
    POSTGRES_POOL.recycleConnection(move connection)

proc initConnectionPool*(
  createConnectionProc: CreateConnectionProc[DbConn] = getDb,
  poolSize: int = 4,
  burstModeDuration: Duration = initDuration(minutes = 30)
) =
  POSTGRES_POOL.initConnectionPool(createConnectionProc, poolSize, burstModeDuration)

proc destroyConnectionPool*() =
  POSTGRES_POOL.destroyConnectionPool()