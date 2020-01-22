######################
Norm: ORM for Nim Apps
######################


.. image:: https://travis-ci.com/moigagoo/norm.svg?branch=develop
    :alt: Build Status
    :target: https://travis-ci.com/moigagoo/norm

.. image:: https://raw.githubusercontent.com/yglukhov/nimble-tag/master/nimble.png
    :alt: Nimble
    :target: https://nimble.directory/pkg/norm


**Norm** is an object-oriented, framework-agnostic ORM for Nim apps that:

Norm supports SQLite and PostgreSQL.

- `Quickstart → <#quickstart>`_
- `API docs → <https://moigagoo.github.io/norm/norm.html>`_
- `Sample app → <https://github.com/moigagoo/norm-sample-webapp>`_
- `Contributing → <#contributing>`_

Install Norm with `Nimble <https://github.com/nim-lang/nimble>`_:

.. code-block:: nim

	$ nimble install norm

Add Norm to your .nimble file:

.. code-block:: nim

	requires "norm"


Quickstart
==========

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
	  dropTables()                            # Drop all tables.


Reference
=========

Listed below are the procs that build up CRUD for manipulating tables and rows in Norm.

These procs can be called in ``withDb`` and ``withCustomDb`` macros regardless of the backend.


Database Setup
--------------

-   ``createTables(force = false)``

    Generate and execute DB schema for all models.

    ``force=true`` prepends ``DROP TABLE IF EXISTS`` for all genereated tables.

    Relevant tests:

    -   https://github.com/moigagoo/norm/develop/tests/tsqlite.nim#49
    -   https://github.com/moigagoo/norm/develop/tests/tpostgres.nim#49


Database Teardown
-----------------

-   ``dropTables(T: typedesc)``

    Drop tables for all models.

    Relevant tests:

    -   https://github.com/moigagoo/norm/develop/tests/tsqlite.nim#255
    -   https://github.com/moigagoo/norm/develop/tests/tpostgres.nim#241


Writing Migrations
------------------

**Note:** Although Norm provides the means to write and apply migrations manually, the plan is to develop a tool to generate migrations from model diffs and apply them with the option to rollback.

-   ``createTable(T: typedesc, force = false)``

    Generate and execute an SQL table schema from a type definition. Column schemas are generated from Nim object field definitions. Basic types are mapped automatically. For custom types, *parser* and *formatter* must be provided.

    Use to update the DB schema after adding new models.

    ``force=true`` prepends `DROP TABLE IF EXISTS` to the generated query.

    Relevant tests:

    -   https://github.com/moigagoo/norm/blob/develop/tests/tsqlitemigrate.nim#L35
    -   https://github.com/moigagoo/norm/blob/develop/tests/tpostgresmigrate.nim#L50

-   ``addColumn(field: typedesc)``

    Generate and execute an SQL query to add a column to an existing table.

    Use to create columns after adding new fields to existing models.

    ``field`` should point to the model field for which the column is to be created, e.g. ``Pet.age``.

    Relevant tests:

    -   https://github.com/moigagoo/norm/blob/develop/tests/tsqlitemigrate.nim#L44
    -   https://github.com/moigagoo/norm/blob/develop/tests/tpostgresmigrate.nim#L61

-   ``dropUnusedColumns(T: typedesc)``

    Recreate the table from a model, losing unmatching columns in the process. This involves creating a temporary table and copying the data there, then dropping the original table and renaming the temporary one to the original one's name.

    Use to clean up DB after removing a field from a model.

    Relevant tests:

    -   https://github.com/moigagoo/norm/blob/develop/tests/tsqlitemigrate.nim#L57
    -   https://github.com/moigagoo/norm/blob/develop/tests/tpostgresmigrate.nim#L79

-   ``renameColumnFrom(field: typedesc, oldName: string)``.

    Rename a DB column to match the model field. Provide ``oldName`` to tell Norm which column you are renaming. This has to be done manually since there's no way to guess the programmer's intetion when they rename a model field: is it to rename the underlying DB column or to remove the old column and create a new one instead?

    Use this proc to rename a column. To replace a column, use `addColumn` with conjunction with ``dropUnusedColumns``.

    Relevant tests:

    -   https://github.com/moigagoo/norm/blob/develop/tests/tsqlitemigrate.nim#L72
    -   https://github.com/moigagoo/norm/blob/develop/tests/tsqlitemigrate.nim#L95
    -   https://github.com/moigagoo/norm/blob/develop/tests/tpostgresmigrate.nim#L89
    -   https://github.com/moigagoo/norm/blob/develop/tests/tpostgresmigrate.nim#L106

-   ``renameTableFrom(T: typedesc, oldName: string)``

    Rename a DB table to match the model name. The old table name must be provided explicitly because when the DB table name for a model changes, there's no way to guess which existing table used to match this model.

    Use after renaming a model or changing its ``dbTable`` pragma value.

    Relevant tests:

    -   https://github.com/moigagoo/norm/blob/develop/tests/tsqlitemigrate.nim#L85
    -   https://github.com/moigagoo/norm/blob/develop/tests/tpostgresmigrate.nim#L98


Delete
------

-   ``dropTable(T: typedesc)``

    Drop table associated with a model.

    Use after removing a model.

    Relevant tests:

    -   https://github.com/moigagoo/norm/develop/tests/tsqlite.nim#L257
    -   https://github.com/moigagoo/norm/develop/tests/tpostgres.nim#L241


Manipulating Rows
-----------------

Create
''''''

- ``insert``


Read
''''

- ``getOne``
- ``getMany``
- ``getAll``


Updates
'''''''

-   ``update``


Delete
''''''

-   ``delete``


Transactions
''''''''''''

-   ``transation``



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
