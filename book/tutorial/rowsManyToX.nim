import std/with
import nimib, nimibook
import norm/[model, sqlite]

import ./tables

nbInit(theme = useNimibook)

nbText: """

### Selecting Many-To-One/One-To-Many relationships

Imagine you had a Many-To-One relationship between two models, like we have with `Customer` being the many-model and `User` being the one-model, where one user can have many customers. 

If you have a user and wanted to query all of their customers, you couldn't do so by just making a query for the user, as that model doesn't have a "seq[Customer]" field that Norm could resolve.

You could query the users for a given customer separately using the mechanisms of a general select statement.

However, you can also query them separately using a convenience proc `selectOneToMany` to do all of that work for you.

Just provide the "one"-side of the relationship (user), a seq of the "many-model" (seq[Customer]) to populate as before and the name of the field on the "many-model" ("user" as that's the name of field on Customer pointing to User) that points to the "one-model" (User).

If your "many-model" (Customer) only has a single field pointing to the one model (User) you can even forego providing the field-name, Norm will infer it for you!
"""

nbCode:
  var 
    userFoo = newUser("foo@foo.foo")
    userBar = newUser("bar@bar.bar")

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

An additional benefit of using this `selectOneToMany` is that with it, Norm will validate whether this query is correct at compile time! 

In the first approach, if Customer doesn't have a field called "user" or if that field does not have any model-type that points to the "User"-table, nor an fk-pragma to any such type, then the code will throw an error with a helpful message at compile-time.

In the second approach, if Customer doesn't have any field of type "User" or any other model-type that points to the same table as "User", it will also not compile while throwing a helpful error message.


### Selecting Many-To-Many relationships

Imagine if you had a Many-To-Many relationship between two models (e.g. Users and Groups) that is recorded on an "join-model" (e.g. UserGroup), where one user can be in many groups and a group can have many users.

If you have a user and want to query all of its groups, you can do so via the general select statement mechanism.

Similarly to `selectOneToMany` there is a helper proc `selectManyToMany` here for convenience.

Just provide the side whose model entry you have (e.g. User or Group), a seq of the join-model (e.g. UserGroup), a seq of the entries your trying to query (e.g. seq[Group] or seq[User]), the field name on the join-model pointing to the model entry you have (e.g. "user" or "group") and the field name on the join-model pointing to the model of the entries you're trying to query (e.g. "group" or "user").

As before, if your join-model (e.g. UserGroup) only has a single field pointing to each of the two many models (e.g. User and Group), you can forego the field names and let Norm infer them for you.
"""

nbCode:
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

nbSave