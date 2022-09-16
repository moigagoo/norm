import std/[times, monotimes, locks, strformat]
import log
import ndb/[sqlite, postgres]

export monotimes
export times
export locks


const
  dbHostEnv* = "DB_HOST"
  dbUserEnv* = "DB_USER"
  dbPassEnv* = "DB_PASS"
  dbNameEnv* = "DB_NAME"

type PoolDefect* = object of Defect

type Connection = sqlite.DbConn | postgres.DbConn
type CreateConnectionProc*[Connection] = proc(): Connection

type ConnectionPool*[Connection] = ref object
  connections*: seq[Connection]
  lock*: Lock
  defaultPoolSize*: int
  burstEndTime*: MonoTime # The point in time after which current burst mode ends if burst mode is active
  isInBurstMode*: bool
  createConnectionProc: CreateConnectionProc[Connection]
  burstModeDuration: Duration 

proc isEmpty*[Connection](pool: ConnectionPool[Connection]): bool = pool.connections.len() == 0
proc isFull*[Connection](pool: ConnectionPool[Connection]): bool = pool.connections.len() >= pool.defaultPoolSize
proc isInitialized*[Connection](pool: ConnectionPool[Connection]): bool = pool != nil

proc refillConnections(pool: var ConnectionPool) =
  ## Creates a number of database connections equal to the size of the connection pool
  ## and adds them to said pool. ONLY use this if you have acquired the lock on the pool!
  if not pool.isInitialized():
    raise newException(PoolDefect, "Tried to use uninitialized database connection pool. Did you forget to call 'initConnectionPool' on startup? ")

  for i in 1..pool.defaultPoolSize:
    pool.connections.add(pool.createConnectionProc())

  log fmt "Refilled database connection pool to {pool.connections.len()} connections"


proc initConnectionPool*[Connection](pool: var ConnectionPool[Connection], createConnectionProc: CreateConnectionProc[Connection], poolSize: int, burstModeDuration: Duration = initDuration(minutes = 30)) =
  ## Initializes the connection pool globally. To do so requires 
  ## the path to the database (`databasePath`) which shall be connected to, 
  ## and the number of connections within the pool under normal load (`poolSize`).
  ## You can also set the initial duration of the burst mode (burstModeDuration)
  ## once it is triggered. burstModeDuration defaults to 30 minutes.

  if pool.isInitialized():
    raise newException(PoolDefect, """Tried to initialize database connection pool a second time""")
  
  pool = ConnectionPool[Connection](
    connections: @[],
    isInBurstMode: false,
    burstEndTime: getMonoTime(),
    defaultPoolSize: poolSize,
    createConnectionProc: createConnectionProc,
    burstModeDuration: burstModeDuration
  )

  initLock(pool.lock)

  pool.refillConnections()

  log fmt "Initialized database connection pool with {pool.connections.len()} connections"


proc activateBurstMode(pool: var ConnectionPool) =
  ## Activates burst mode on the connection pool. Burst mode is active
  ## for a limited time after activation, determined by the burstModeDuration
  ## set during initialization. While active, it allows the pool to contain more
  ## connections than it can contain by default and replenishes the connections 
  ## within the pool. If triggered while burst mode is already active, this 
  ## will refill the pool and reset the timer.
  pool.isInBurstMode = true
  pool.burstEndTime = getMonoTime() + pool.burstModeDuration
  
  pool.refillConnections()


proc updateBurstModeState*[Connection](pool: var ConnectionPool[Connection]) =
  ## Checks whether the burst mode on the connection pool has run out and turns
  ## it off if so. Does nothing if burst mode is already off.
  if not pool.isInBurstMode:
    return

  if getMonoTime() > pool.burstEndTime:
    pool.isInBurstMode = false

    log "Deactivated Burst Mode on database connection pool"


proc extendBurstModeLifetime*[Connection](pool: var ConnectionPool[Connection]) =
  ## Delays the time after which burst mode is turned off for the given pool.
  ## If the point in time is further away from now than the pools boostModeDuration
  ## then the time is not extended. Throws a DbError if burst mode lifetime is
  ## attempted to be extended while pool is not in burst mode.
  if pool.isInBurstMode == false:
    log "Tried to extend  database connection pool's burst mode while pool wasn't in burst mode. You have a logic issue!"

  let hasAlreadyMaxBurstModeDuration: bool = pool.burstEndTime - getMonoTime() > pool.burstModeDuration
  if hasAlreadyMaxBurstModeDuration:
    return

  pool.burstEndTime = pool.burstEndTime + initDuration(seconds = 5)


proc borrowConnection*[Connection](pool: var ConnectionPool[Connection]): Connection {.gcsafe.} =
  ## Tries to borrow a database connection from the connection pool.
  ## This operation is thread-safe, as it locks the pool while trying to
  ## borrow a connection from it.
  ## Can activate burst mode if larger amounts of connections are necessary.
  ## Extends the pools burst mode if it is in burst mode and need for
  ## the same level of connections is still present.
  if not pool.isInitialized():
    raise newException(PoolDefect, """Tried to borrow a connection from an uninitialized/destroyed database connection pool!""")
  
  withLock pool.lock:
    if pool.isEmpty():
      pool.activateBurstMode()

    elif not pool.isFull() and pool.isInBurstMode: 
      pool.extendBurstModeLifetime()
      
    result = pool.connections.pop()

    log fmt "Number of connections in database connection pool: {pool.connections.len()}"

proc recycleConnection*[Connection](pool: var ConnectionPool[Connection], connection: Connection) {.gcsafe.} =
  ## Recycles a connection and tries to return it to the pool.
  ## This operation is thread-safe, as it locks the pool while trying to return
  ## the connection.
  ## If the pool is full and not in burst mode, the connection is superfluous 
  ## and thusclosed and garbage collected.
  ## If the pool is in burst mode, it will allow an unlimited number of 
  ## connections into the pool.
  if not pool.isInitialized():
    raise newException(PoolDefect, """Tried to recycle a connection back into an uninitialized/destroyed database connection pool!""")
  
  withLock pool.lock:
    pool.updateBurstModeState()

    if pool.isFull() and not pool.isInBurstMode:
      connection.close()
    else:
      pool.connections.add(connection)

    log fmt "Number of connections in database connection pool: {pool.connections.len()}"


proc destroyConnectionPool*[Connection](pool: var ConnectionPool[Connection]) =
  ## Destroys the currently initialized pool. This also ensures that all
  ## connections currently within the pool are closed.
  if not pool.isInitialized():
    return

  for connection in pool.connections:
    connection.close()
  
  pool = nil

  log fmt "Destroyed database connection pool"


template withDb*(body: untyped): untyped =
  ## Wrapper for DB operations.

  ## Borrows a database connection ``DbConn`` from the connection pool,
  ## runs your code in a ``try`` block and returns the connection to the pool.

  block: #ensures db connection exists only within the scope of this block
    let db {.inject.} = borrowConnection()

    try:
      body

    finally:
      recycleConnection(connection)
