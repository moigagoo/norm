# Norm, a Nim ORM

[![Build Status](https://travis-ci.com/moigagoo/norm.svg?branch=develop)](https://travis-ci.com/moigagoo/norm)

[![Nimble](https://raw.githubusercontent.com/yglukhov/nimble-tag/master/nimble.png)](https://nimble.directory/pkg/norm)


**Norm** is a lightweight ORM written in [Nim programming language](https://nim-lang.org). It enables you to store Nim's objects as DB rows and fetch data from DB as objects. So that your business logic is driven with objects, and the storage aspect is decoupled from it.

Norm supports SQLite and PostgreSQL.

- [Quickstart →](#Quickstart)
- [API docs →](https://moigagoo.github.io/norm/norm.html)
- [Sample app →](https://github.com/moigagoo/norm-sample-webapp)
- [Contributing info →](#contributing)


## Installation

Install Norm with Nimble:

```shell
$ nimble install norm
```


## Quickstart

```nim
import norm/sqlite                        # Import SQLite backend.
# import norm/postgres                    # Import PostgreSQL backend.
import logging                            # Import logging to inspect the generated SQL statements.
import unicode, sugar, options

db("petshop.db", "", "", ""):             # Set DB connection credentials.
  type                                    # Describe object model in an ordinary type section.
    User = object
      age: Positive                       # Nim types are automatically converted into SQL types
                                          # and back.
                                          # You can specify how types are converted using
                                          # ``parser``, ``formatter``, ``parseIt``,
                                          # and ``formatIt`` pragmas.
      name {.
        formatIt: capitalize(it)          # Enforce that ``name`` is stored in DB capitalized.
      .}: string
      ssn: Option[int]                    # ``Option`` fields are allowed to be NULL in DB.

addHandler newConsoleLogger()

withDb:                                   # Start a DB session.
  createTables(force=true)                # Create tables for objects. Drop tables if they exist.

  var bob = User(                         # Create a ``User`` instance as you normally would.
    age: 23,                              # Note that the instance is mutable. This is mandatory.
    name: "bob",
    ssn: some 456
  )
  bob.insert()                            # Insert ``bob`` into DB.
  dump bob.id                             # ``id`` attr is added by Norm and updated on insertion.

  var alice = User(age: 12, name: "alice", ssn: none int)
  alice.insert()

withCustomDb("mirror.db", "", "", ""):    # Override default DB credentials defined in ``db``.
  createTables(force=true)

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
```


## Disclaimer

My goal with Norm was to lubricate the routine of working with DB: creating DB schema from the object model and converting data between DB and object representations. It's a tool for *common* cases not for *all* cases. Norm's builtin CRUD procs will help you write a typical RESTful API, but as your app grows more complex, you will have to write SQL queries manually (btw Norm can help with that too).

**Using any ORM, Norm included, doesn't free a programmer from having to learn SQL!**


## Contributing

1.  Any contributions are welcome, be it pull requests, code reviews, documentation improvements, bug reports, or feature requests.

2.  If you decide to contribute through code, please run the tests after you change the code:

```shell
$ docker-compose run tests                        # run all tests in Docker
$ docker-compose run test tests/testpostgres.nim  # run a single test suite in Docker
$ nimble test                                     # run all tests natively;
                                                  # requires a running PostgreSQL server!
$ nim c -r tests/testsqlite.nim                   # run a single test suite natively
```

3.  Use camelCase instead of snake_case.

4.  New procs must have a documentation comment. If you modify an existing proc, update the comment.


### ❤ Contributors ❤

- [@moigagoo](https://github.com/moigagoo)
- [@alaviss](https://github.com/alaviss)
