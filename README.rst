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
    # For postgres, import `norm/[model, postgres]`


    type
      # Models are ref objects inherited from `Model`
      User = ref object of Model
        name: string
        age: Natural

      Pet = ref object of Model
        species: string
        # Fields that are `Model` themselves are treated as foreign keys
        owner: Option[User]


    # It is strongly recommended to follow the Nim convention and define init functions for your models
    func newUser(name = "", age = 0): User = User(name: name, age: age)

    func newPet(species = "", owner = none User): Pet = Pet(species: species, owner: owner)


    when isMainModule:
      # This is a regular `ndb.sqlite.DbConn` database connection
      let dbConn = open(":memory:", "", "", "")

      # Make sure the objects you want to insert into or update in the database are mutable
      var
        alice = newUser("Alice", 23)
        bob = newUser("Bob", 45)
        snowflake = newPet("cat", some alice)
        fido = newPet("dog", some bob)
        spot = newPet("dog")

        users = [alice, bob]
        pets = [snowflake, fido, spot]

      # Create tables and populate the db in a transaction
      dbConn.transaction:
        with dbConn:
          createTables(snowflake)

          # Note that `insert` updates the passed `Model` instances
          insert(users)
          insert(pets)

      # To update a record, modify its object and call `update` on it
      spot.owner = some bob
      dbConn.update(spot)

      # Use Nim's `dup` syntax to select data from the db into immutable objects.
      let
        # Note that we're passing `Pet` instances without `owner` field
        dogs = @[newPet()].dup:
          dbConn.select("species = ?", "dog")

      for dog in dogs:
        # Because each `dog` doesn't have an `owner`, `owner` information is never fetched.
        echo "dog.id = $#, dog.species = $#, dog.owner.isNone = $#" %
          [$dog.id, $dog.species, $dog.owner.isNone]

      # The more data you pass to `select`, the more data you get from the db.
      # Here, we pass `Pet` instances with `User` references in them.
      let bobsPets = @[newPet("", some newUser())].dup:
        dbConn.select("User.name = ?", "Bob")

      for pet in bobsPets:
        # Because we passed `Pet` instances with `owner` fields, Norm fetches `owner` field too, in a single `JOIN` query
        echo "pet.id = $#, pet.species = $#, pet.owner.name = $#" %
          [$pet.id, $pet.species, $(get pet.owner).name]

      # Chaining procs gives you a fancy way to filter and delete records
      discard @[newPet()].dup:
        dbConn.select("species = ?", "dog")
        dbConn.delete

      # `dup` allows you to select records in-place, without storing the result into a variable
      for pet in @[newPet()].dup(dbConn.select("1")):
        echo "$#" % $pet[]

      close dbConn


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
