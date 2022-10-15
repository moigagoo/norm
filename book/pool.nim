import nimib, nimibook


nbInit(theme = useNimibook)

nbText: """
# Connection Pool

Connection pooling is a technique that involves precreating and reusing a number of ever-open DB connections instead of opening connections on demand. Since opening and closing connections takes more time than passing open connections around, this technique is used to improve performance of web application under high load.

Norm offers a simple thread-safe connection pool implementation. It can be used with both Postgres and SQLite, and you even can create multiple pools if you need to.

**Important** Connection pooling requires `--mm:orc`.

To use connection pool:
1. create a [`Pool`](/apidocs/norm/pool.html#Pool) instance by calling [`newPool`](/apidocs/norm/pool.html#newPool,Positive)
2. wrap your DB calls in a [`withDb`](/apidocs/norm/pool.html#withDb.t,Pool,untyped)

`newPool` creates a pool of a given size with connections of type `DbConn` (either from [`sqlite`](/apidocs/norm/sqlite.html) or [`postgres`](/apidocs/norm/postgres.html)). The params for the connections are taken from the environment, similar to how `withDb` works (see [Configuration from Environment](/config.html)).
"""

nbCode:
  import norm/[model, sqlite, pool]


  type
    Product = ref object of Model
      name: string
      price: float

  proc newProduct(): Product =
    Product(name: "", price: 0.0)

  putEnv("DB_HOST", ":memory:")

  var connPool = newPool[DbConn](10)

  withDb(connPool):
    db.exec sql"PRAGMA foreign_keys = ON"
    db.createTables(newProduct())
  
nbText: """
## Pool Exhausted Policy

If the app requests more connections from the pool than it can give, we say the pool is exhausted.

There are two ways a pool can react to that:
1. raise a [`PoolExhaustedError`](/apidocs/norm/pool.html#PoolExhaustedError); this is the default policy
2. open an additional connection and extend the pool size

The policy is set during the pool creation by setting `poolExhaustedPolicy` param to either `pepRaise` or `pepExtend`.

To reset the pool back to its default size after it has been extended, call [`reset`](/apidocs/norm/pool.html#reset,Pool) proc on it.


## Manual Pool Manipulation

You can borrow connections from the pool manually by calling [`pop`](/apidocs/norm/pool.html#add%2CPool%2CT) proc.

**Important** If you choose to get connections from the pool manually, you must care about putting the borrowed connections back byb calling [`add`](/apidocs/norm/pool.html#add,Pool,T).
"""

nbSave

