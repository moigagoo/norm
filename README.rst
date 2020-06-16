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

-   `Repo <https://github.com/moigagoo/norm>`__
    -   `Issues <https://github.com/moigagoo/norm/issues>`__
    -   `Pull requests <https://github.com/moigagoo/norm/pulls>`__
-   `Sample app <https://github.com/moigagoo/norm-sample-webapp>`__
-   `API index <theindex.html>`__
-   `Changelog <https://github.com/moigagoo/norm/blob/develop/changelog.rst>`__

Norm works best with `Norman <https://moigagoo.github.io/norman/norman.html>`__.


Quickstart
==========

Install Norm with `Nimble <https://github.com/nim-lang/nimble>`_:

.. code-block::

    $ nimble install norm

Add Norm to your .nimble file:

.. code-block:: nim

    requires "norm"

Here's a brief intro to Norm. Save as ``hellonorm.nim`` and run with ``nim r hellonorm.nim``:

.. code-block:: nim

    import options
    import std/with
    import sugar
    import strutils

    # Add a logger to see the generated queries
    import logging; addHandler newConsoleLogger(fmtStr = "\t")

    import norm/[model, sqlite]
    # For PostgreSQL, import `norm/[model, postgres]`


    type
      # Define models as ref objects of ``Model``
      User = ref object of Model
        name: string
        age: Natural

      Pet = ref object of Model
        species: string
        # ``Option`` types mean nullable SQL columns; non-``Option`` fields are ``NOT NULL``
        # Fields of type ``Model`` are converted to foreign keys
        owner: Option[User]


    # It is strongly recommended to follow the Nim convention and define init functions for your models
    func newUser(name = "", age = 0): User = User(name: name, age: age)

    func newPet(species = "", owner = none User): Pet = Pet(species: species, owner: owner)


    when isMainModule:
      # This is a regular ``ndb.sqlite.DbConn`` connection
      let dbConn = open(":memory:", "", "", "")

      # Instantiate ``var`` objects to insert and update rows
      var
        alice = newUser("Alice", 23)
        bob = newUser("Bob", 45)
        snowflake = newPet("cat", some alice)
        fido = newPet("dog", some bob)
        spot = newPet("dog")

        users = [alice, bob]
        pets = [snowflake, fido, spot]

      # Create tables and populate the db. Optionally, wrap in a transaction.
      dbConn.transaction:
        with dbConn:
          createTables(snowflake)

          # This add each ``users`` member and updates its ``id``
          insert(users)
          insert(pets)

      # To update a record, modify the object and call ``update``
      spot.owner = some bob
      dbConn.update(spot)

      # To select rows, you can use immutable variables.
      # Nim's ``dup`` syntax fits great to collect data:
      let
        # Passing a ``seq[Model]`` to ``select`` selects many rows.
        # Pass a single ``Model`` instance to fetch only one row.
        dogs = @[newPet()].dup:
          dbConn.select("species = ?", "dog")

      for dog in dogs:
        # Each ``dog`` was created with ``newPet`` without argument, so its ``owner`` field was ``None``.
        # This tells Norm not to fetch rows for owners.
        echo "dog.id = $#, dog.species = $#, dog.owner.isNone = $#" %
          [$dog.id, $dog.species, $dog.owner.isNone]

      # Here, we pass ``Pet`` instances with ``User`` references.
      # This tells Norm to fetch ``owner`` rows for each ``pet`` with a single ``JOIN`` query.
      let bobsPets = @[newPet("", some newUser())].dup:
        dbConn.select("User.name = ?", "Bob")

      for pet in bobsPets:
        # This time, ``owner`` is ``Some`` and can be resolved:
        echo "pet.id = $#, pet.species = $#, pet.owner.name = $#" %
          [$pet.id, $pet.species, $(get pet.owner).name]

      # The ``dup`` syntax provides a really nice way of chaining DB queries.
      # Here, we filter records by a condition and delete them:
      discard @[newPet()].dup:
        dbConn.select("species = ?", "dog")
        dbConn.delete

      # ``dup`` allows you to select records in-place, without storing the result into a variable:
      for pet in @[newPet()].dup(dbConn.select("1")):
        echo "$#" % $pet[]

      close dbConn


Tutorial
=========

Models
------

**A model** is an abstraction for a unit of your app's business logic. For example, in an online shop, the models might be Product, Customer, and Discount. Sometimes, models are created for entities that are not visible for the end user, but that are necessary from the architecture point of view: User, CartItem, or Permission.

Models can relate to each each with one-to-one, one-to-many, many-to-many relations. For example, a CartItem can have many Discounts, whereas as a single Discount can be applied to many Products.

Models can also inherit from each other. For example, Customer may inherit from User.

**In Norm**, Models are ref objects inherited from ``Model`` root object:

.. code-block:: nim

    import norm/model

    type
      User = ref object of Model
        email: string

From a model definition, Norm deduces SQL queries to create tables and insert, select, update, and delete rows. Norm converts Nim objects to rows, their fields to columns, and their types to SQL types and vice versa.

For example, for a model definition like the one above, Norm generates the following table schema:

.. code-block:: sql

    CREATE TABLE IF NOT EXISTS "User"(email TEXT NOT NULL, id INTEGER NOT NULL PRIMARY KEY)

Inherited models are just inherited objects:

.. code-block:: nim

    type
      Customer = ref object of User
        name: string

To create relations between models, define fields subtyped from ``Model``:

.. code-block:: nim

    type
      User = ref object of Model
        email: string

      Customer = ref object of Model
        name: string
        user: User


Create Tables
-------------

Let's create some tables and examine the queries generated by Norm.

Create a file called ``normapp.nim`` with this code:

.. code-block:: nim

    import logging; addHandler newConsoleLogger()
    import options

    import norm/[model, sqlite]


    type
      User = ref object of Model
        email: string

      Customer = ref object of Model
        name: Option[string]
        user: User


    func newUser(email = ""): User =
      User(email: email)

    func newCustomer(name = none string, user = newUser()): Customer =
      Customer(name: name, user: user)


    let dbConn = open("normapp.db", "", "", "")

    dbConn.createTables(newCustomer())

    close dbConn

Run the file with ``nim r normapp.nim``. You'll see the generated queries in stdout (formatting added to improve readability):

.. code-block:: sql

    CREATE TABLE IF NOT EXISTS "User"(
        email TEXT NOT NULL,
        id INTEGER NOT NULL PRIMARY KEY
    )

    CREATE TABLE IF NOT EXISTS "Customer"(
        name TEXT,
        user INTEGER NOT NULL,
        id INTEGER NOT NULL PRIMARY KEY,
        FOREIGN KEY(user) REFERENCES "User"(id)
    )

Let's take a closer look at this line:

.. code-block:: nim

    dbConn.createTables(newCustomer())

``createTables`` proc takes a model instance and generates a table schema for it. For each of the instance's fields, a column is generated. If a field is itself a ``Model``, a foreign key is added. ``Option`` fields are nullable, non-``Option`` ones are ``NOT NULL``.

Note that a single ``createTables`` call generated two table schemas. That's because model ``Customer`` refers to ``User``, and therefore its table can't be created without the table for ``User`` existing beforehand. Norm makes sure all dependency tables are created before creating the one that ``createTables`` was actually called with. That's actually why the proc is called ``createTables`` and not ``createTable``.

    Make sure to instantiate models with ``Model`` fields so that these fields are not ``nil``. Otherwise, Norm won't be able to create a table schema for them.

To keep the code more explicit, feel free to call both ``dbConn.createTables(newUser())`` and ``dbConn.createTables(newCustomer())``. The worst thing to happen is the same query being called twice, but since they both have a ``IF NOT EXISTS`` constraint, the table will be created only once.

    Note that ``id`` column is created despite not being present in ``User`` definition. That's because it's a special read-only field maintained automatically by Norm. It represents row id in the database.

    **Do not define id field or manually update its value.**


Insert Rows
-----------

To insert rows, use ``insert`` procs. There is a variant that takes a single model instance or a sequence of them.

instances passed to ``insert`` must be mutable for Norm to be able to update their ``id`` fields.

Add ``import std/with`` line to imports and this code before ``close dbConn``:

.. code-block:: nim

    var
      user1 = newUser("foo@foo.foo")
      user2 = newUser("bar@bar.bar")
      alice = newCustomer(some "Alice", user1)
      bob = newCustomer(some "Bob", user1)
      sam = newCustomer(some "Sam", user2 )

      users = [user1, user2]

    with dbConn:
      insert users

      insert alice
      insert bob

      insert user2
      insert sam

Run the code and examine the queries (previous queries omitted for readability):

.. code-block:: sql

    INSERT INTO "User" (email) VALUES(?) <- @['foo@foo.foo']
    INSERT INTO "Customer" (name, user) VALUES(?, ?) <- @['Alice', 3]
    INSERT INTO "Customer" (name, user) VALUES(?, ?) <- @['Bob', 3]
    INSERT INTO "User" (email) VALUES(?) <- @['bar@bar.bar']
    INSERT INTO "Customer" (name, user) VALUES(?, ?) <- @['Sam', 4]

When Norm attempts to insert ``alice``, it will see that ``user1`` that it referenced in it has not been inserted, so there's no ``id`` to store in foreign key. So, Norm inserts ``user1`` automatically and then uses its new ``id`` (in this case, 1) as the foreign key value.

With ``bob``, there's no need to do that since ``user1`` is already in the database.

You can insert dependency models explicitly to make the code more verbose, as we do with ``user2`` and ``sam``.


Contributing
============

Any contributions are welcome: pull requests, code reviews, documentation improvements, bug reports, and feature requests.

-   See the [issues on GitHub](http://github.com/moigagoo/norm/issues).

-   Run the tests before and after you change the code.

    The recommended way to run the tests is via [Docker](https://www.docker.com/) and [Docker Compose](https://docs.docker.com/compose/):

    .. code-block::

        $ docker-compose run --rm tests                     # run all test suites
        $ docker-compose run --rm test tests/tmodel.nim     # run a single test suite

-   Use camelCase instead of snake_case.

-   New procs must have a documentation comment. If you modify an existing proc, update the comment.

-   Apart from the code that implements a feature or fixes a bug, PRs are required to ship necessary tests and a changelog updates.


❤ Contributors ❤
------------------

Norm would not be where it is today without the efforts of these fine folks: `https://github.com/moigagoo/norm/graphs/contributors <https://github.com/moigagoo/norm/graphs/contributors>`_
