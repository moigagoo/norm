import std/[options, strformat]

import nimib, nimibook
import norm/sqlite

import tables


nbInit
nbUseNimibook

nbText: """
# Rows

## Insert Rows

To insert rows, use `insert` procs. There is a variant that takes a single model instance or a sequence of them.

Instances passed to `insert` must be mutable for Norm to be able to update their `id` fields.

In your inim session, run:
"""

nbCode:
  var
    userFoo = newUser("foo@foo.foo")
    userBar = newUser("bar@bar.bar")
    alice = newCustomer(some "Alice", userFoo)
    bob = newCustomer(some "Bob", userFoo)
    sam = newCustomer(some "Sam", userBar)
    aliceAndBob = [alice, bob]

nbText: """
Those are the objects we'll insert as rows in the database:
"""

nbCode:
  import std/with

  with dbConn:
    insert aliceAndBob
    insert userBar
    insert sam

nbText: &"""
When Norm attempts to insert `alice`, it detects that `userFoo` that it referenced in it has not been inserted yet, so there's no `id` to store as foreign key. So, Norm inserts `userFoo` automatically and then uses its new `id` (in this case, {userFoo.id}) as the foreign key value.

With `bob`, there's no need to do that since `userFoo` is already in the database.


## Select Rows

To select a rows with Norm, you instantiate a model that serves as a container for the selected data and call `select`.

One curious thing about `select` is that its result depends not only on the condition you pass but also on the container. If the container has `Model` fields that are not `None`, Norm will select the related rows in a single `JOIN` query giving you a fully populated model object. However, if the container has a `none Model` field, it is just ignored.

In other words, Norm will automatically handle the "n+1" problem.

Let's see how that works:
"""

nbCode:
  var customerBar = newCustomer()
  dbConn.select(customerBar, "User.email = ?", "bar@bar.bar")

nbText: """
Let's examine how Norm populated `customerBar`:
"""

nbCode:
  echo customerBar[]

nbCode:
  echo customerBar.user[]

nbText: """
If you pass a sequence to `select`, you'll get many rows:
"""

nbCode:
  var customersFoo = @[newCustomer()]
  dbConn.select(customersFoo, "User.email = ?", "foo@foo.foo")

nbText: """
The generated query is similar to the previous one, but the result is populated objects, not one:
"""

nbCode:
  for customer in customersFoo:
    echo customer[]
    echo customer.user[]

nbText: """
## Count Rows

Selecting rows is expensive if many rows are fetched. Knowing the number of rows you have before doing the actual select is useful.

To count the rows without fetching them, use `count`:
"""

nbCode:
  echo dbConn.count(Customer)

nbText: """
To count only unique records, use `dist = true` in conjunction with the column name you want to check for uniqueness:
"""

nbCode:
  echo dbConn.count(Customer, "user", dist = true)

nbText: """
You can also count rows matching condition:
"""

nbCode:
  echo dbConn.count(Customer, "*", dist = false, "name LIKE ?", "alice")


nbText: """
## Update Rows

To update a row, you just update the object and call `update` on it:
"""

nbCode:
  customerBar.name = some "Saaam"
  dbConn.update(customerBar)

nbText: """
Since customer references a user, to update a customer, we also need to update its user. Norm handles that automatically by generating two queries.

Updating rows in bulk is also possible:
"""

nbCode:
  for customer in customersFoo:
    customer.name = some ("Mega" & get(customer.name))

  dbConn.update(customersFoo)

nbText: """
For each object in `customersFoo`, a pair of queries are generated.

## Delete Rows

To delete a row, call `delete` on an object:
"""

nbCode:
  dbConn.delete(sam)

nbText: """
After deletion, the object becomes `nil`:
"""

nbCode:
  echo sam.isNil

nbSave

