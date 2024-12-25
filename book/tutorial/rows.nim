import std/[options, strformat]

import nimib, nimibook
import norm/sqlite

import tables


nbInit(theme = useNimibook)

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

  echo()

nbText: &"""
When Norm attempts to insert `alice`, it detects that `userFoo` that it referenced in it has not been inserted yet, so there's no `id` to store as foreign key. So, Norm inserts `userFoo` automatically and then uses its new `id` (in this case, {userFoo.id}) as the foreign key value.

With `bob`, there's no need to do that since `userFoo` is already in the database.

When inserting Norm Model, it is possible to force the id to a given value by setting the id attribute of the Model. In order for the insertion to proceed, it is necessary to specify ``force=true`` when inserting:
"""

nbCode:
  var userBaz = newUser("baz@baz.baz")
  userBaz.id = 156
  with dbConn:
    insert(userBaz, force = true)
  echo "userBaz.id == 156 ?", (userBaz.id == 156)

  echo()

nbText: &"""
## Select Row

### Select in general

To select a rows with norm, you instantiate a model that serves as a container for the selected data and call `select`.

One curious thing about `select` is that its result depends not only on the condition you pass but also on the container. If the container has `Model` fields that are not `None`, Norm will select the related rows in a single `JOIN` query giving you a fully populated model object. However, if the container has a `none Model` field, it is just ignored.

In other words, Norm will automatically handle the "n+1" problem.

Let's see how that works:
"""

nbCode:
  var customerBar = newCustomer()
  dbConn.select(customerBar, "User.email = ?", "bar@bar.bar")

  echo()

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

  echo()

nbText: """
The generated query is similar to the previous one, but the result is populated objects, not one:
"""

nbCode:
  for customer in customersFoo:
    echo customer[]
    echo customer.user[]

nbText: """
You can pass a `Model` subtype to `select` proc instead of the object instance. Norm will instantiate the container object implicitly:
"""

nbCode:
  let userFoo2 = dbConn.select(User, "email = ?", "foo@foo.foo")
  echo()

nbText: """
Note that this will only work with types that can be instantiated by calling `new <Type>`, i.e. types that don't require explicit instantiation.

If you query relationships that are nested, such as when customers can have pets and you want to query all pets of all customers of users with a specific email address, you will need  to concatenate the foreign-key fields, separeted by a `_` in your query.
"""

nbCode:
  import norm/model

  type Pet* = ref object of Model
    name*: string
    owner*: Customer

  func newPet*(name = "", owner = newCustomer()): Pet =
    Pet(name: name, owner: owner)
  
  dbConn.createTables(newPet())
  
  var fluffi: Pet = newPet("Fluffi", bob)
  dbConn.insert(fluffi)


  var petsFoo = @[newPet()]
  dbConn.select(petsFoo, "owner_user.email LIKE ?", "foo%")

  for pet in petsFoo:
    echo pet[]

nbText"""
## Update Rows

To update a row, you just update the object and call `update` on it:
"""

nbCode:
  customerBar.name = some "Saaam"
  dbConn.update(customerBar)

  echo()

nbText: """
Since customer references a user, to update a customer, we also need to update its user. Norm handles that automatically by generating two queries.

Updating rows in bulk is also possible:
"""

nbCode:
  for customer in customersFoo:
    customer.name = some ("Mega" & get(customer.name))

  dbConn.update(customersFoo)

  echo()

nbText: """

## Delete Rows

To delete a row, call `delete` on an object:
"""

nbCode:
  dbConn.delete(sam)

  echo()

nbText: """
After deletion, the object becomes `nil`:
"""

nbCode:
  echo sam.isNil

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
## Sum Column Values

To get a sum of column values, use `sum` proc:
"""

nbCode:
  import norm/model

  type Chair = ref object of Model
    legCount: Natural

  func newChair(legCount = 0): Chair = Chair(legCount: legCount)

  dbConn.createTables(newChair())

  var
    threeLeggedChair = newChair(3)
    fourLeggedChair = newChair(4)
    anotherFourLeggedChair = newChair(4)

  dbConn.insert(threeLeggedChair)
  dbConn.insert(fourLeggedChair)
  dbConn.insert(anotherFourLeggedChair)

  echo dbConn.sum(Chair, "legCount")
  echo dbConn.sum(Chair, "legCount", dist = true)
  echo dbConn.sum(Chair, "legCount", dist = false, "legCount > ?", 3)

nbText: """
## Check If Row Exists

If you need to check if a row selected by a given condition exists, use `exists` proc:
"""

nbCode:
  echo dbConn.exists(Customer, "name = ?", "Alice")

nbSave
