import nimib, nimibook
import norm/sqlite
import ./tables
import std/[with, options]

nbInit(theme = useNimibook)

nbText: """
# More complex queries
Norm allows you to sort, limit use subqueries for complex where clauses and more.
To understand how, it helps to keep in mind that norm essentially generates SQL queries after the following pattern:
  `SELECT <fields of model> FROM <table-name specified by model> WHERE <condition>`.

This means that whatever pieces of SQL come after the WHERE keyword are thing you can freely specify if need be.

## Limiting the number of queried models
To limit the number of queried models, simply use SQL's Limit keyword.

Lets query our `Customer` table from earlier and query multiple entries, but only take the first entry.
"""

nbCode:
  var
    userFoo = newUser("foo@foo.foo")
    alice = newCustomer(some "Alice", userFoo)
    bob = newCustomer(some "Bob", userFoo)
  with dbConn:
    insert userFoo
    insert alice
    insert bob

  var customersFoo = @[newCustomer()]
  dbConn.select(customersFoo, "User.email = ? LIMIT 1", "foo@foo.foo")
  
  assert customersFoo.len() == 1
  
  echo()

nbText: """
`customersFoo` has only 1 entry, despite `alice` and `bob` both having the email address `"foo@foo.foo"`, thanks to the LIMIT SQL keyword.

## Sorting model output
We can of course use ORDER BY just as we did LIMIT before:
"""

nbCode:
  var sortedCustomersFoo = @[newCustomer()]
  dbConn.select(sortedCustomersFoo, "User.email = ? ORDER BY name DESC", "foo@foo.foo")
  
  assert sortedCustomersFoo[0].name.get() == "Bob"
  assert sortedCustomersFoo[1].name.get() == "Alice"
  
  echo()


nbText: """
## Using Subqueries
Similarly as to ORDER BY, you can also use subqueries withint he WHERE block:
"""
nbCode:
  var subqueryCustomersFoo = @[newCustomer()]
  const condition = """
    Customer.id IN (SELECT Cust.id FROM Customer AS Cust WHERE Cust.id % 2 == 0)
  """
  dbConn.select(subqueryCustomersFoo, condition)
  assert subqueryCustomersFoo.len() == 1
  assert subqueryCustomersFoo[0].id == 2
  
  echo()
nbSave