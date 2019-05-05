##[
###############
Norm, a Nim ORM
###############

**Norm** is a lightweight ORM written in `Nim programming language <https://nim-lang.org>`__. It enables you to store Nim's objects as DB rows and fetch data from DB as objects. So that your business logic is driven with objects, and the storage aspect is decoupled from it.

Norm supports SQLite and PostgreSQL.

- `API docs → <https://moigagoo.github.io/norm/norm.html>`__
- `Sample app → <https://github.com/moigagoo/norm-sample-webapp>`__

==========
Quickstart
==========

.. code-block:: nim
    import norm / sqlite                      # Import SQLite backend.
    # import norm / postgres                  # Import PostgreSQL backend.
    import logging                            # Import logging to inspect the generated SQL statements.
    import unicode, sugar

    db("petshop.db", "", "", ""):             # Set DB connection credentials.
      type                                    # Describe object model in an ordinary type section.
        User = object
          age: int                            # Nim types are automatically converted into SQL types
                                              # and back.
                                              # You can specify how types are converted using
                                              # ``parser``, ``formatter``, ``parseIt``,
                                              # and ``formatIt`` pragmas.
          name {.
            formatIt: capitalize(it)          # Enforce that ``name`` is stored in DB capitalized.
          .}: string

    addHandler newConsoleLogger()

    withDb:                                   # Start a DB session.
      createTables(force=true)                # Create tables for objects. Drop tables if they exist.

      var bob = User(                         # Create a ``User`` instance as you normally would.
        name: "bob",                          # Note that the instance is mutable. This is mandatory!
        age: 23
      )
      bob.insert()                            # Insert ``bob`` into DB.
      dump bob.id                             # ``id`` attr is added by Norm and updated on insertion.

      var bobby = User(name: "bobby", age: 34)
      bobby.insert()

      var alice = User(name: "alice", age: 12)
      alice.insert()

    withDb:
      let bobs = User.getMany(                # Read records from DB:
        100,                                  # - only the first 100 records
        cond="name LIKE 'Bob%' ORDER BY age"  # - find by condition
      )

      dump bobs

    withDb:
      var bob = User.getOne(1)                # Fetch record from DB and store it as ``User`` instance.
      bob.age += 10                           # Change attr value.
      bob.update()                            # Update the record in DB.

      bob.delete()                            # Delete the record.
      dump bob.id                             # ``id`` is 0 for objects not stored in DB.

    withDb:
      dropTables()                            # Drop all tables.
]##

import norm / [rowutils, objutils]
import norm / pragmas
import norm / [sqlite, postgres]
