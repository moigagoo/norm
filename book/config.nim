import nimib, nimibook

import tutorial/tables


nbInit(theme = useNimibook)

nbText: """
# Configuration from Environment

In a real-life project, you want to keep your DB configuration separate from the code. Common pattern is to put it in environment variables, probably in a `.env` file that's processed during the app startup.

Norm's `getDb` proc lets you create a DB connection using `DB_HOST`, `DB_USER`, `DB_PASS`, and `DB_NAME` environment variables:
"""

nbCode:
  import std/[os, options]

  import norm/sqlite


  putEnv("DB_HOST", ":memory:")

  let db = getDb()

  var
    customerFoo = newCustomer(some "Alice", newUser("foo@foo.foo"))
    customerBar = newCustomer()

  db.createTables(customerBar)
  db.insert(customerFoo)
  db.select(customerBar, "User.email = ?", "foo@foo.foo")

  echo customerBar[]

nbText: """
`withDb` template is even handier as it lets you run code without explicitly creating or closing a DB connection:
"""

nbCode:
  var
    customerSpam = newCustomer(some "Bob", newUser("bar@bar.bar"))
    customerEggs = newCustomer()

  withDb:
    db.createTables(customerEggs)
    db.insert(customerSpam)
    db.select(customerEggs, "User.email = ?", "bar@bar.bar")

  echo customerBar[]

nbSave

