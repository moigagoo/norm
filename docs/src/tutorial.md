# Tutorial

In this tutorial, we'll create a webapp using Jester web framework and Norm. It's an online petshop.

The entire apps is available at https://github.com/moigagoo/norm-sample-webapp

!!! note
    Norm can be used with any framework or without a framework at all. Jester is just the most popular one for Nim at the moment of writing.

    Also, we're using SQLite just for the sake of simplicity.


## Define Models

In Norm, models are generated from regular Nim object definitions.

Create a file called `models.nim` and define regular Nim objects in it:

    import times

    type
      Owner* = object
        firstName*: string
        lastName*: string
        birthDate*: DateTime
      Pet* = object
        name*: string
        age: Natural

To turn it into a model, import `norm/sqlite` and wrap the type section with `db` macro:

    import times
    import norm/sqlite

    db("petshop.db", "", "", ""):
      type
        Owner* = object
          firstName*: string
          lastName*: string
          birthDate*: DateTime
        Pet* = object
          name*: string
          age: Natural

Models provide an interface to the DB: you manage tables and the data in them by calling procs on models and their instances.


## Create Tables

To create tables from the models, call `createTables` inside a `withDb` block:

    withDb:
      createTables()

`withDb` sets up a context for database access: opens a connection to the DB using credentials from `db` invocation and defines procs to manipulate the tables and data. `createTables` is one of such procs.

Compile and run `models.nim` to create the tables:

  $ nim c -r models.nim


## Populate Tables

To add data to the tables, call `insert` on a model instance:

    withDb:
      var
        bob = Owner(
          firstName: "Bob",
          lastName: "Bobton",
          birthDate: "1988-01-30".parse("yyyy-MM-dd", utc())
        )
        spot = Pet(
          name: "Spot",
          age: 3
        )

    insert bob
    insert spot

Note that the instances are mutable. When a row is inserted into the DB, its ID is propagated to the corresponding model instance.

So, after the `insert` call, you can get the unique identifier of the inserted row:

  echo bob.id
  # prints: 1

You don't have to define `id` field in your models manually. Norm injects it automatically. The initial value is `0`, which means that this model instance hasn't been inserted in the DB yet.
