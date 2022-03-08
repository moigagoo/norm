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

  echo()

nbText: &"""
When Norm attempts to insert `alice`, it detects that `userFoo` that it referenced in it has not been inserted yet, so there's no `id` to store as foreign key. So, Norm inserts `userFoo` automatically and then uses its new `id` (in this case, {userFoo.id}) as the foreign key value.

With `bob`, there's no need to do that since `userFoo` is already in the database.


## Select Row
### Select in general
To select a rows with Norm, you instantiate a model that serves as a container for the selected data and call `select`.

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
### Selecting Many-To-One/One-To-Many relationships
Imagine you had a Many-To-One relationship between two models, like we have with `Customer` being the many-model and `User` being the one-model, where one user can have many customers. 

If you have a user and wanted to query all of their customers, you couldn't do so by just making a query for the user, as that model doesn't have a "seq[Customer]" field that norm could resolve.

You could query the users for a given customer separately using the mechanisms of a general select statement.

However, you can also query them separately using a convenience proc `selectOneToMany` to do all of that work for you.

Just provide the "one"-side of the relationship (user), a seq of the "many-model" (seq[Customer]) to populate as before and the name of the field on the "many-model" ("user" as that's the name of field on Customer pointing to User) that points to the "one-model" (User).

If your "many-model" (Customer) only has a single field pointing to the one model (User) you can even forego providing the field-name, norm will infer it for you!
"""

nbCode:
  # With explicitly provided field name
  var customersFoo2 = @[newCustomer()]
  dbConn.selectOneToMany(userFoo, customersFoo2, "user")

  for customer in customersFoo2:
    echo customer[]

  # With inferred field name
  var customersFoo3 = @[newCustomer()]
  dbConn.selectOneToMany(userFoo, customersFoo3)
    
  for customer in customersFoo3:
    echo customer[]

nbText: """

An additional benefit of using this `selectOneToMany` is that with it, norm will validate whether this query is correct at compile time! 

In the first approach, if Customer doesn't have a field called "user" or if that field does not have any model-type that points to the "User"-table, nor an fk-pragma to any such type, then the code will throw an error with a helpful message at compile-time.

In the second approach, if Customer doesn't have any field of type "User" or any other model-type that points to the same table as "User", it will also not compile while throwing a helpful error message.

### Selecting Many-To-Many relationships
Imagine if you had a Many-To-Many relationship between two models (e.g. Users and Groups) that is recorded on an "join-model" (e.g. UserGroup), where one user can be in many groups and a group can have many users.

If you have a user and want to query all of its groups, you can do so via the general select statement mechanism.

Similarly to `selectOneToMany` there is a helper proc `selectManyToMany` here for convenience.

Just provide the side whose model entry you have (e.g. User or Group), a seq of the join-model (e.g. UserGroup), a seq of the entries your trying to query (e.g. seq[Group] or seq[User]), the field name on the join-model pointing to the model entry you have (e.g. "user" or "group") and the field name on the join-model pointing to the model of the entries you're trying to query (e.g. "group" or "user").

As before, if your join-model (e.g. UserGroup) only has a single field pointing to each of the two many models (e.g. User and Group), you can forego the field names and let norm infer them for you.
"""

nbCode:
  import norm/model

  type
    Group* = ref object of Model
      name*: string
    
    UserGroup* = ref object of Model
      user*: User
      membershipGroup*: Group

  func newGroup*(name = ""): Group = Group(name: name)
  
  func newUserGroup*(user = newUser(), group = newGroup()): UserGroup = UserGroup(user: user, membershipGroup: group)

  dbConn.createTables(newGroup())
  dbConn.createTables(newUser())
  dbConn.createTables(newUserGroup())

  var
    groupFoo = newGroup("groupFoo")
    groupBar = newGroup("groupBar")

    userFooGroupFooMembership = newUserGroup(userFoo, groupFoo)
    userBarGroupFooMembership = newUserGroup(userBar, groupFoo)
    userFooGroupBarMembership = newUserGroup(userFoo, groupBar)

  with dbConn:
    insert groupFoo
    insert groupBar
    insert userFooGroupFooMembership
    insert userBarGroupFooMembership
    insert userFooGroupBarMembership

  # With explicitly provided fieldnames
  var userFooGroupMemberships: seq[UserGroup] = @[newUserGroup()]
  var userFooGroups: seq[Group] = @[newGroup()]
  dbConn.selectManyToMany(userFoo, userFooGroupMemberships, userFooGroups, "user", "membershipGroup")
  
  for group in userFooGroups:
    echo group[]

  # With inferred field names
  var userFooGroupMemberships2: seq[UserGroup] = @[newUserGroup()]
  var userFooGroups2: seq[Group] = @[newGroup()]
  dbConn.selectManyToMany(userFoo, userFooGroupMemberships2, userFooGroups2)

  for group in userFooGroups2:
    echo group[]

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
For each object in `customersFoo`, a pair of queries are generated.

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

nbSave

