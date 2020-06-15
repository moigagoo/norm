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

Here's a brief intro to Norm. Save as ``hellonorm.nim`` and run with ``nim c -r hellonorm.nim``:

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
        # Passing a ``seq[Model]`` to ``select`` selects many rows. Pass a single ``Model`` instance to fetch only one row.
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

From a model definition, Norm deduces SQL queries to create tables and insert, select, update, and delete rows.

For example, for a model definition like this, Norm generates the following table schema:

.. code-block:: sql

    CREATE TABLE IF NOT EXISTS "User"(email TEXT NOT NULL, id INTEGER NOT NULL PRIMARY KEY)

Note that a column named ``id`` is created despite not being present in ``User`` object definition. That's because it's a special field inherited from ``Model``. **You should never define your own ``id`` field or manually update its value for Model instances.**

Inherited models are just inherited objects:

.. code-block:: nim

    type
      Customer = ref object of User
        name: string

This model is represented with the following schema:

.. code-block:: sql

    CREATE TABLE IF NOT EXISTS "Customer"(name TEXT NOT NULL, email TEXT NOT NULL, id INTEGER NOT NULL PRIMARY KEY)


However, in this paricular case, a one-to-one relation may be more suitable. To create relations between models, define fields subtyped from ``Model``:

.. code-block:: nim

    type
      User = ref object of Model
        email: string

      Customer = ref object of Model
        user: User
        name: string

This gets you:

.. code-block:: sql

    CREATE TABLE IF NOT EXISTS "User"(email TEXT NOT NULL, id INTEGER NOT NULL PRIMARY KEY)
    CREATE TABLE IF NOT EXISTS "Customer"(user INTEGER NOT NULL, name TEXT NOT NULL, id INTEGER NOT NULL PRIMARY KEY, FOREIGN KEY(user) REFERENCES "User"(id))


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
