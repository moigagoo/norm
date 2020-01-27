***************
Norm: A Nim ORM
***************

.. image:: https://travis-ci.com/moigagoo/norm.svg?branch=develop
    :alt: Build Status
    :target: https://travis-ci.com/moigagoo/norm

.. image:: https://raw.githubusercontent.com/yglukhov/nimble-tag/master/nimble.png
    :alt: Nimble
    :target: https://nimble.directory/pkg/norm


**Norm** is an object-oriented, framework-agnostic ORM for Nim that supports SQLite and PostgreSQL.


Quickstart
==========

Install Norm with `Nimble <https://github.com/nim-lang/nimble>`_:

.. code-block:: nim

    $ nimble install norm

Add Norm to your .nimble file:

.. code-block:: nim

    requires "norm"

Here's a brief intro to Norm. Save as ``hellonorm.nim`` and run with ``nim c -r hellonorm.nim``:

.. code-block:: nim

	import norm/sqlite                        # Import SQLite backend; ``norm/postgres`` for PostgreSQL.

	import unicode, options                   # Norm supports `Option` type out of the box.

	import logging                            # Import logging to inspect the generated SQL statements.
	addHandler newConsoleLogger()


	db("petshop.db", "", "", ""):             # Set DB connection credentials.
	  type                                    # Describe models in a type section.
	    User = object                         # Model is a Nim object.
	      age: Positive                       # Nim types are automatically converted into SQL types
	                                          # and back.
	                                          # You can specify how types are converted using
	                                          # ``parser``, ``formatter``,
	                                          # ``parseIt``, and ``formatIt`` pragmas.
	      name {.
	        formatIt: ?capitalize(it)         # E.g., enforce ``name`` stored in DB capitalized.
	      .}: string
	      ssn: Option[int]                    # ``Option`` fields are allowed to be NULL.


	withDb:                                   # Start DB session.
	  createTables(force=true)                # Create tables for objects.
	                                          # ``force=true`` means “drop tables if they exist.”

	  var bob = User(                         # Create a ``User`` instance as you normally would.
	    age: 23,                              # You can use ``initUser`` if you want.
	    name: "bob",                          # Note that the instance is mutable. This is necessary,
	    ssn: some 456                         # because implicit ``id``attr is updated on insertion.
	  )
	  bob.insert()                            # Insert ``bob`` into DB.
	  echo "Bob ID = ", bob.id                # ``id`` attr is added by Norm and updated on insertion.

	  var alice = User(age: 12, name: "alice", ssn: none int)
	  alice.insert()

	withCustomDb("mirror.db", "", "", ""):    # Override default DB credentials
	  createTables(force=true)                # to connect to a different DB with the same models.

	withDb:
	  let bobs = User.getMany(                # Read records from DB:
	    100,                                  # - only the first 100 records
	    cond="name LIKE 'Bob%' ORDER BY age"  # - matching condition
	  )

	  echo "Bobs = ", bobs

	withDb:
	  var bob = User.getOne(1)                # Fetch record from DB and store it as ``User`` instance.
	  bob.age += 10                           # Change attr value.
	  bob.update()                            # Update the record in DB.

	  bob.delete()                            # Delete the record.
	  echo "Bob ID = ", bob.id                # ``id`` is 0 for objects not stored in DB.

    withDb:
      transaction:                            # Put multiple statements under ``transaction`` to run
        for i in 1..10:                       # them as a single DB transaction. If any operation fails,
          var user = User(                    # the entire transaction is cancelled.
            age: 20+i,
            name: "User " & $i,
            ssn: some i
          )
          insert user

	withDb:
	  dropTables()                            # Drop all tables.


See also:

- `Sample app → <https://github.com/moigagoo/norm-sample-webapp>`_
- `API index → <theindex.html>`_


Reference Guide
===============

Listed below are the procs for manipulating tables and rows in Norm.

These procs can be called in ``withDb`` and ``withCustomDb`` macros regardless of the backend.


Setup
-----

    ``createTables(force = false)``

    Generate and execute DB schema for all models.

    ``force=true`` prepends ``DROP TABLE IF EXISTS`` for all genereated tables.

    Implementation:

    -   SQLite: https://github.com/moigagoo/norm/blob/develop/src/norm/sqlite.nim#L95
    -   PostgreSQL: https://github.com/moigagoo/norm/blob/develop/src/norm/postgres.nim#L91

    Tests:

    -   https://github.com/moigagoo/norm/blob/develop/tests/tsqlite.nim#L47
    -   https://github.com/moigagoo/norm/blob/develop/tests/tpostgres.nim#L48


Teardown
--------

-   ``dropTables(T: typedesc)``

    Drop tables for all models.

    Implementation:

    -   SQLite: https://github.com/moigagoo/norm/blob/develop/src/norm/sqlite.nim#L70
    -   PostgreSQL: https://github.com/moigagoo/norm/blob/develop/src/norm/postgres.nim#L66

    Tests:

    -   https://github.com/moigagoo/norm/blob/develop/tests/tsqlite.nim#L255
    -   https://github.com/moigagoo/norm/blob/develop/tests/tpostgres.nim#L241
    -   https://github.com/moigagoo/norm/blob/develop/tests/tsqlitefromtypes.nim#L90
    -   https://github.com/moigagoo/norm/blob/develop/tests/tpostgresfromtypes.nim#L85



Create Records
--------------

-   ``insert(obj: var object, force=false)``

    Store a model instance into the DB as a row.

    The input object must be mutable because its ``id`` field, initially equal ``0``, is updated after the insertion to reflect the row ID returned by the DB.

    Implementation:

    -   SQLite: https://github.com/moigagoo/norm/blob/develop/src/norm/sqlite.nim#L168
    -   PostgreSQL: https://github.com/moigagoo/norm/blob/develop/src/norm/postgres.nim#L59

    Tests:

    -   https://github.com/moigagoo/norm/blob/develop/tests/tsqlite.nim#L48
    -   https://github.com/moigagoo/norm/blob/develop/tests/tpostgres.nim#L49
    -   https://github.com/moigagoo/norm/blob/develop/tests/tsqlitefromtypes.nim#L19
    -   https://github.com/moigagoo/norm/blob/develop/tests/tpostgresfromtypes.nim#L20


Read Records
------------

-   ``getOne(T: typedesc, id: int)``

    Fetch one row by ID and store it into a new model instance.

    Implementation:

    -   SQLite: https://github.com/moigagoo/norm/blob/develop/src/norm/sqlite.nim#L223
    -   PostgreSQL: https://github.com/moigagoo/norm/blob/develop/src/norm/postgres.nim#L228

    Tests:

    -   https://github.com/moigagoo/norm/blob/develop/tests/tsqlite.nim#L141
    -   https://github.com/moigagoo/norm/blob/develop/tests/tpostgres.nim#L127


-   ``getOne(obj: var object, id: int)``

    Fetch one row by ID and store it into as existing instance.

    Implementation:

    -   SQLite: https://github.com/moigagoo/norm/blob/develop/src/norm/sqlite.nim#L209
    -   PostgreSQL: https://github.com/moigagoo/norm/blob/develop/src/norm/postgres.nim#L214

    Tests:

    -   https://github.com/moigagoo/norm/blob/develop/tests/tsqlite.nim#L141
    -   https://github.com/moigagoo/norm/blob/develop/tests/tpostgres.nim#L127

-   ``getOne(T: typedesc, cond: string, params: varargs[DbValue, dbValue])``

    Fetch the first row that matches the given condition. Store into a new instance.

    Implementation:

    -   SQLite: https://github.com/moigagoo/norm/blob/develop/src/norm/sqlite.nim#L201
    -   PostgreSQL: https://github.com/moigagoo/norm/blob/develop/src/norm/postgres.nim#L206

    Tests:

    -   https://github.com/moigagoo/norm/blob/develop/tests/tsqlite.nim#L141
    -   https://github.com/moigagoo/norm/blob/develop/tests/tpostgres.nim#L127

-   ``getOne(obj: var object, cond: string, params: varargs[DbValue, dbValue])``

    Fetch the first row that matches the given condition. Store into an existing instance.

    Implementation:

    -   SQLite: https://github.com/moigagoo/norm/blob/develop/src/norm/sqlite.nim#L183
    -   PostgreSQL: https://github.com/moigagoo/norm/blob/develop/src/norm/postgres.nim#L188

    Tests:

    -   https://github.com/moigagoo/norm/blob/develop/tests/tsqlite.nim#L141
    -   https://github.com/moigagoo/norm/blob/develop/tests/tpostgres.nim#L127

-   ``getMany(T: typedesc, limit: int, offset = 0, cond = "TRUE", params: varargs[DbValue, dbValue])``

    Fetch at most ``limit`` rows from the DB that math the given condition with the given params. The result is stored into a new sequence of model instances.

    Implementation:

    -   SQLite: https://github.com/moigagoo/norm/blob/develop/src/norm/sqlite.nim#L247
    -   PostgreSQL: https://github.com/moigagoo/norm/blob/develop/src/norm/postgres.nim#L252

    Tests:

    -   https://github.com/moigagoo/norm/blob/develop/tests/tsqlite.nim#L197
    -   https://github.com/moigagoo/norm/blob/develop/tests/tpostgres.nim#L183

-   ``getMany(objs: var seq[object], limit: int, offset = 0, cond = "TRUE", params: varargs[DbValue, dbValue])``

    Fetch at most ``limit`` rows from the DB that math the given condition with the given params. The result is stored into an existing sequence of model instances.

    Implementation:

    -   SQLite: https://github.com/moigagoo/norm/blob/develop/src/norm/sqlite.nim#L228
    -   PostgreSQL: https://github.com/moigagoo/norm/blob/develop/src/norm/postgres.nim#L233

    Tests:

    -   https://github.com/moigagoo/norm/blob/develop/tests/tsqlite.nim#L197
    -   https://github.com/moigagoo/norm/blob/develop/tests/tpostgres.nim#L183

-   ``getAll(T: typedesc, cond = "TRUE", params: varargs[DbValue, dbValue])``

    Get all rows from a table that match the given condition.

    **Warning:** This is a dangerous operation because you're fetching an unknown number of rows, which could be millions. Consider using ``getMany`` instead.

    Implementation:

    -   SQLite: https://github.com/moigagoo/norm/blob/develop/src/norm/sqlite.nim#L258
    -   PostgreSQL: https://github.com/moigagoo/norm/blob/develop/src/norm/postgres.nim#L263

    Tests:

    -   https://github.com/moigagoo/norm/blob/develop/tests/tsqlite.nim#L197
    -   https://github.com/moigagoo/norm/blob/develop/tests/tpostgres.nim#L183


Update Records
--------------

-   ``update(obj: object, force = false)``

    Update a record in the DB with the current field values of a model instance.


    Implementation:

    -   SQLite: https://github.com/moigagoo/norm/blob/develop/src/norm/sqlite.nim#L279
    -   PostgreSQL: https://github.com/moigagoo/norm/blob/develop/src/norm/sqlite.nim#L284

    Tests:

    -   https://github.com/moigagoo/norm/blob/develop/tests/tsqlite.nim#L224
    -   https://github.com/moigagoo/norm/blob/develop/tests/tpostgres.nim#L210


Delete Records
--------------

-   ``delete(obj: var object)``

    Delete a record from the DB by ID from a model instance. The instance's ``id`` fields is set to ``0``.

    Implementation:

    -   SQLite: https://github.com/moigagoo/norm/blob/develop/src/norm/sqlite.nim#L293
    -   PostgreSQL: https://github.com/moigagoo/norm/blob/develop/src/norm/sqlite.nim#L298

    Tests:

    -   https://github.com/moigagoo/norm/blob/develop/tests/tsqlite.nim#L240
    -   https://github.com/moigagoo/norm/blob/develop/tests/tpostgres.nim#L226


Transactions
------------

-   ``transaction``

    Implementation:

    -   SQLite:
    -   PostgreSQL:

    Tests:

    -   asd
    -   asd


Migrations
----------

**Note:** Although Norm provides the means to write and apply migrations manually, the plan is to develop a tool to generate migrations from model diffs and apply them with the option to rollback.

-   ``createTable(T: typedesc, force = false)``

    Generate and execute an SQL table schema from a type definition. Column schemas are generated from Nim object field definitions. Basic types are mapped automatically. For custom types, *parser* and *formatter* must be provided.

    Use to update the DB schema after adding new models.

    ``force=true`` prepends `DROP TABLE IF EXISTS` to the generated query.

    Implementation:

    -   SQLite: https://github.com/moigagoo/norm/blob/develop/src/norm/sqlite.nim#L83
    -   PostgreSQL: https://github.com/moigagoo/norm/blob/develop/src/norm/postgres.nim#L79

    Tests:

    -   https://github.com/moigagoo/norm/blob/develop/tests/tsqlitemigrate.nim#L35
    -   https://github.com/moigagoo/norm/blob/develop/tests/tpostgresmigrate.nim#L50

-   ``addColumn(field: typedesc)``

    Generate and execute an SQL query to add a column to an existing table.

    Use to create columns after adding new fields to existing models.

    ``field`` should point to the model field for which the column is to be created, e.g. ``Pet.age``.

    Implementation:

    -   SQLite: https://github.com/moigagoo/norm/blob/develop/src/norm/sqlite.nim#L115
    -   PostgreSQL: https://github.com/moigagoo/norm/blob/develop/src/norm/postgres.nim#L111

    Tests:

    -   https://github.com/moigagoo/norm/blob/develop/tests/tsqlitemigrate.nim#L44
    -   https://github.com/moigagoo/norm/blob/develop/tests/tpostgresmigrate.nim#L61

-   ``dropUnusedColumns(T: typedesc)``

    Recreate the table from a model, losing unmatching columns in the process. This involves creating a temporary table and copying the data there, then dropping the original table and renaming the temporary one to the original one's name.

    Use to clean up DB after removing a field from a model.

    Implementation:

    -   SQLite: https://github.com/moigagoo/norm/blob/develop/src/norm/sqlite.nim#L124
    -   PostgreSQL: https://github.com/moigagoo/norm/blob/develop/src/norm/postgres.nim#L129

    Tests:

    -   https://github.com/moigagoo/norm/blob/develop/tests/tsqlitemigrate.nim#L57
    -   https://github.com/moigagoo/norm/blob/develop/tests/tpostgresmigrate.nim#L79

-   ``renameColumnFrom(field: typedesc, oldName: string)``.

    Rename a DB column to match the model field. Provide ``oldName`` to tell Norm which column you are renaming. This has to be done manually since there's no way to guess the programmer's intetion when they rename a model field: is it to rename the underlying DB column or to remove the old column and create a new one instead?

    Use this proc to rename a column. To replace a column, use `addColumn` with conjunction with ``dropUnusedColumns``.

    Implementation:

    -   SQLite: https://github.com/moigagoo/norm/blob/develop/src/norm/sqlite.nim#L144
    -   PostgreSQL: https://github.com/moigagoo/norm/blob/develop/src/norm/postgres.nim#L149

    Tests:

    -   https://github.com/moigagoo/norm/blob/develop/tests/tsqlitemigrate.nim#L72
    -   https://github.com/moigagoo/norm/blob/develop/tests/tsqlitemigrate.nim#L95
    -   https://github.com/moigagoo/norm/blob/develop/tests/tpostgresmigrate.nim#L89
    -   https://github.com/moigagoo/norm/blob/develop/tests/tpostgresmigrate.nim#L106

-   ``renameTableFrom(T: typedesc, oldName: string)``

    Rename a DB table to match the model name. The old table name must be provided explicitly because when the DB table name for a model changes, there's no way to guess which existing table used to match this model.

    Use after renaming a model or changing its ``dbTable`` pragma value.

    Implementation:

    -   SQLite: https://github.com/moigagoo/norm/blob/develop/src/norm/sqlite.nim#L156
    -   PostgreSQL: https://github.com/moigagoo/norm/blob/develop/src/norm/postgres.nim#L161

    Tests:

    -   https://github.com/moigagoo/norm/blob/develop/tests/tsqlitemigrate.nim#L85
    -   https://github.com/moigagoo/norm/blob/develop/tests/tpostgresmigrate.nim#L98


-   ``dropTable(T: typedesc)``

    Drop table associated with a model.

    Use after removing a model.

    Implementation:

    -   SQLite: https://github.com/moigagoo/norm/blob/develop/src/norm/sqlite.nim#L63
    -   PostgreSQL: https://github.com/moigagoo/norm/blob/develop/src/norm/postgres.nim#L59

    Tests:

    -   https://github.com/moigagoo/norm/blob/develop/tests/tsqlite.nim#L257
    -   https://github.com/moigagoo/norm/blob/develop/tests/tpostgres.nim#L241


Contributing
============

Any contributions are welcome: pull requests, code reviews, documentation improvements, bug reports, and feature requests.

-   See the [issues on GitHub](http://github.com/moigagoo/norm/issues).

-   Run the tests before and after you change the code.

    The recommended way to run the tests is via [Docker](https://www.docker.com/) and [Docker Compose](https://docs.docker.com/compose/):

    .. code-block::

	    $ docker-compose run --rm tests                     # run all test suites
	    $ docker-compose run --rm test tests/tpostgres.nim  # run a single test suite

    If you don't mind running two PostgreSQL servers on `postgres_1` and `postgres_2`, feel free to run the test suites natively:

    .. code-block::

	    $ nimble test

    Note that you only need the PostgreSQL servers to run the PostgreSQL backend tests, so:

    .. code-block::

	    $ nim c -r tests/tsqlite.nim    # doesn't require PostgreSQL servers, but requires SQLite
	    $ nim c -r tests/tobjutils.nim  # doesn't require anything at all

-   Use camelCase instead of snake_case.

-   New procs must have a documentation comment. If you modify an existing proc, update the comment.

-   Apart from the code that implements a feature or fixes a bug, PRs are required to ship necessary tests and a changelog updates.


❤ Contributors ❤
------------------

Norm would not be where it is today without the efforts of these fine folks: `https://github.com/moigagoo/norm/graphs/contributors <https://github.com/moigagoo/norm/graphs/contributors>`_
