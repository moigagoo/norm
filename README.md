[![Build Status](https://travis-ci.com/moigagoo/norm.svg?branch=develop)](https://travis-ci.com/moigagoo/norm)

[![Nimble](https://raw.githubusercontent.com/yglukhov/nimble-tag/master/nimble.png)](https://nimble.directory/pkg/norm)


# Norm: ORM for Nim Apps

**Norm** is an object-oriented, framework-agnostic ORM for Nim apps that:

Norm supports SQLite and PostgreSQL.

- [Quickstart →](#Quickstart)
- [API docs →](https://moigagoo.github.io/norm/norm.html)
- [Sample app →](https://github.com/moigagoo/norm-sample-webapp)
- [Contributing info →](#contributing)

Install Norm with [Nimble](https://github.com/nim-lang/nimble/):

    $ nimble install norm

Add Norm to your .nimble file:

    requires "norm"


## Quickstart

```nim
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
```


## Contributing

Any contributions are welcome: pull requests, code reviews, documentation improvements, bug reports, and feature requests.

-   See the [issues on GitHub](http://github.com/moigagoo/norm/issues).

-   Run the tests before and after you change the code.

    The recommended way to run the tests is via [Docker](https://www.docker.com/) and [Docker Compose](https://docs.docker.com/compose/):

        $ docker-compose run --rm tests                     # run all test suites
        $ docker-compose run --rm test tests/tpostgres.nim  # run a single test suite

    If you don't mind running two PostgreSQL servers on `postgres_1` and `postgres_2`, feel free to run the test suites natively:

        $ nimble test

    Note that you only need the PostgreSQL servers to run the PostgreSQL backend tests, so:

        $ nim c -r tests/tsqlite.nim    # doesn't require PostgreSQL servers, but requires SQLite
        $ nim c -r tests/tobjutils.nim  # doesn't require anything at all

-   Use camelCase instead of snake_case.

-   New procs must have a documentation comment. If you modify an existing proc, update the comment.

-   Apart from the code that implements a feature or fixes a bug, PRs are required to ship necessary tests and a changelog updates.


### ❤ Contributors ❤

Norm would not be where it is today without the efforts of these fine folks: [https://github.com/moigagoo/norm/graphs/contributors](https://github.com/moigagoo/norm/graphs/contributors)
