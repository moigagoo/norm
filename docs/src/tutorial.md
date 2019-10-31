# Tutorial

In this tutorial, we'll create a webapp using Jester web framework and Norm. It's an online petshop.

The entire apps is available at https://github.com/moigagoo/norm-sample-webapp

!!! note
    Norm can be used with any framework or without a framework at all. Jester is just the most popular one for Nim at the moment of writing.

    Also, we're using SQLite just for the sake of simplicity.


## Your First Model

In Norm, models are generated from regular Nim object definitions.

Create a file called `models.nim` and define a regular Nim object in it:

    import times

    type
      Owner* = object
        firstName*: string
        lastName*: string
        birthDate*: DateTime

To turn it into a model, import `norm/sqlite` and wrap the type section with `db` macro:

    import times
    import norm/sqlite

    db("petshop.db", "", "", ""):
      type
        Owner* = object
          firstName*: string
          lastName*: string
          birthDate*: DateTime

Congrats! Your first Norm model is ready!


## Create Tables

From the model definition above, Norm can set up the actual database tables. It'll automatically guess the types of the columns that correspond to the Nim types of the object fields.

To create the tables call `createTables`:

    withDb:
      createTables(force=true)

`withDb` sets up a context for procs that require database access. `force=true` means "drop tables if they already exist," just in case.

Compile and run `models.nim` and you have yourself a blank database. You only need to do that once.


## Populate Tables

