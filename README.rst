###############
Norm, a Nim ORM
###############

**Norm** is a lightweight ORM written in `Nim programming language <https://nim-lang.org>`__. It enables you to store Nim's objects as DB rows and fetch data from DB as objects. So that your business logic is driven with objects, and the storage aspect is decoupled from it.

Norm supports SQLite and PostgreSQL.

.. important:: Disclaimer

    My goal with Norm was to lubricate the routine of working with DB: creating DB schema from the object model and converting data between DB and object representations. It's a tool for *common* cases not for *all* cases. Norm's builtin CRUD procs will help you write a typical RESTful API, but as your app grows more complex, you will have to write SQL queries manually (btw Norm can help with that too).

    Using any ORM, Norm included, doesn't free a programmer from having to learn SQL!

- `API docs → <https://moigagoo.github.io/norm/norm.html>`__
- `Sample app → <https://github.com/moigagoo/norm-sample-webapp>`__


============
Installation
============

Install Norm with Nimble:

.. code-block:: shell

    $ nimble install norm


==========
Quickstart
==========

.. code-block:: nim

    import norm / sqlite            # Import SQLite backend. Another option is ``norm / postgres``.
    import logging                  # Import logging to inspect the generated SQL statements.

    db("petshop.db", "", "", ""):   # Set DB connection credentials.
      type                          # Describe object model in an ordinary type section.
        User = object
          name: string
          age: int

    when isMainModule:
      addHandler newConsoleLogger()

      withDb:                       # Start a DB session.
        createTables()              # Create tables for all objects.

        var bob = User(             # Create a ``User`` instance as you normally would.
          name: "Bob",              # Note that ``bob`` is mutable. This is mandatory!
          age: 23
        )
        bob.insert()                # Insert ``bob`` into DB.
        echo bob.id                 # ``id`` attr is added by Norm and updated on insertion.

      withDb:
        var bob = User.getOne(1)    # Fetch record from DB and store it as ``User`` instance.
        bob.age += 10               # Change attr value.
        bob.update()                # Update the record in DB.

        bob.delete()                # Delete the record.
        echo bob.id                 # ``id`` is 0 for objects not stored in DB.

      withDb:
        let bobs = User.getMany(    # Read records from DB:
          100,                      # - only the first 100 records
          where="name LIKE 'Bob%'", # - find by condition
          orderBy="age DESC"        # - order by age from oldest to youngest
        )

      withDb:
        dropTables()                # Drop all tables.
