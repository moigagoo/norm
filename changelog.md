# Changelog

-   [!]—backward incompatible change
-   [+]—new feature
-   [f]—bugfix
-   [r]—refactoring
-   [t]—test suite improvement
-   [d]—docs improvement


## 2.8.4 (December 24, 2024

- [f] Fix connection pool creation for Nim 2.2.0 (see [#206](https://github.com/moigagoo/norm/pull/206)).


## 2.8.3 (July 5, 2024)

- [f] Make creating indices idempotent (see [#203](https://github.com/moigagoo/norm/pull/203)).


## 2.8.2 (January 30, 2024)

- [+] PostgreSQL: Add the ability to set custom schema name for models (see [#202](https://github.com/moigagoo/norm/pull/202)).


## 2.8.1 (August 11, 2023)

- [f] version bump lowdb to fix failed import of db_connector on nim 2.0.0


## 2.8.0 (April 5, 2023)

- [+] Bulk update is now performed in a single query which speeds up execution 1000 times (see [#188](https://github.com/moigagoo/norm/issues/188)).
- [+] Enum Support (see [#166](https://github.com/moigagoo/norm/issues/166)).


## 2.7.0 (February 27, 2023)

- [+] Norm is not Nim 2.0 compatible (see [#182](https://github.com/moigagoo/norm/issues/182)).
- [f] DB interactions are now GC-safe (see [#167](https://github.com/moigagoo/norm/issues/167)).
- [r] ndb dependency has been replaced with lowdb.
- [r] Improve exception tracking accuracy.
- [t] Tons of improvements with regard to GitHub Actions and nimble tasks to run the test suite.


## 2.6.2 (February 9, 2023)

- [+] Add `LIMIT 1` to the single object variant of `select` proc to make selection faster.
- [f] Add `PRAGMA foreign_keys=on` to sqlite connections upon creation, for both the pool and when using `getDb`.


## 2.6.1 (December 12, 2022)

- [+] Add the ability to create indexes for tables (see [#180](https://github.com/moigagoo/norm/issues/180)).


## 2.6.0 (October 18, 2022)

- [+] App connection pool (see [#50](https://github.com/moigagoo/norm/issues/50)).


## 2.5.2 (September 14, 2022)

- [+] Added `rawSelect` proc, which allows you execute raw SQL and have the output be parsed into a custom object-type.
- [+] `insert` with `obj.id != 0` and `force=true` now uses the id provided. For PostgreSQL, this means adding conflictPolicy with `ON CONFLICT DO...` clause.
- [r] Logging: refactored `log` module to not trigger warnings when `normDebug` is not defined.
- [r] Slightly changed how objects are being parsed, leading to a small performance increase.


## 2.5.1 (July 20, 2022)
- [+] Added `uniqueGroup` pragma to provide UNIQUE constraint on multiple columns (see [#136](https://github.com/moigagoo/norm/issues/136)).
- [+] Add `readOnly` alias for `ro` pragma (see [#128](https://github.com/moigagoo/norm/issues/128)).
- [f] Fixed further points where compile-time assertions created unused variables.
- [f] Fixed `selectOneToMany` and `selectManyToMany` that were introduced in 2.5.1 being unable to deal with FK fields that were Optionals or directly ids.
- [t] Enable deepCopy for tests to prepare for the `--mm:arc|orc` switch in Nim 2.0.


## 2.5.0 (July 8, 2022)

- [+] Added `selectOneToMany` proc overload that is able to query multiple many-to-one relationships at once (see [#142](https://github.com/moigagoo/norm/issues/142)).
- [+] Added `selectManyToMany` proc overload that is able to query multiple many-to-many relationships at once (see [#142](https://github.com/moigagoo/norm/issues/142)).
- [d] Added small hint that placeholders in postgres is done via `$1`, `S2`... etc.
- [d] Added links to norman, example app, the API index and these nimibook docs.


## 2.4.1 (Jun 23, 2022)

-   [r] Replaced pointless variable assignments at compile time with `static discard`.
-   [r] Improved error message you receive when using `selectManyToMany` with an invalid joinModel.


## 2.4.0 (March 7, 2022)

-   [+] Added `selectOneToMany` proc to query many-to-one relationships (see [#127](https://github.com/moigagoo/norm/issues/127))
-   [+] Added `selectManyToMany` proc to query many-to-many relationships (see [#127](https://github.com/moigagoo/norm/issues/127))


## 2.3.7 (February 22, 2022)

-   [f] Fix tests for self-ref foreign keys.
-   [t] Run tests of PRs.


## 2.3.6 (February 22, 2022)

-   [f] Fix generic models for Nim <= 1.6.4. The same fix has been merged in ``std/macros``, in the devel branch of the compiler but will not be backported to 1.6 (see [#132](https://github.com/moigagoo/norm/issues/132)).
-   [f] Fix self-referencing optional foreign key, handled manually through ``fk`` pragmas (see [#137](https://github.com/moigagoo/norm/issues/137) ).


## 2.3.5 (January 17, 2022)

-   [+] Add `sum` proc to calculate column value sum.


## 2.3.4 (January 16, 2022)

-   [+] Add the ability to define read-only models (see [#125](https://github.com/moigagoo/norm/issues/125)).
-   [+] Add `exists` proc to check if a row exists (see [#115](https://github.com/moigagoo/norm/issues/115)).
-   [r] Remove `nimibook` from dependencies to speed up package builds.


## 2.3.3 (December 26, 2021)

-   [+] SQLite: Add `conflictPolicy` param to `insert` procs. It determines how insertion conflicts should be handled: `cpRaise` (default) means raise an `DbError`, `cpIgnore` means keep the old row and ignore the new one, and `cpReplace` means replace the old row (see [#120](https://github.com/moigagoo/norm/issues/120)).

## 2.3.2 (November 19, 2021)

-   [+] Add `norm.model.fCol` func variant that works with typedescs. Now `fCol` func variants are symmetrical to `col`.
-   [+] Add `tableName` pragma to specify custom table name for model (see [#117](https://github.com/moigagoo/norm/issues/117)).
-   [f] Add missing exceptions to `select` procs (see [#116](https://github.com/moigagoo/norm/issues/116)).


## 2.3.1 (September 29, 2021)

-   [r][d] Add `{.raises.}` annotations to `select` procs to make it more explicit that they raise a `NotFoundError` if the requested row is not in the DB.   


## 2.3.0 (April 8, 2021)

-   [!][+] Objects with `id` != 0 are now not inserted multiple times by default. To force insertion, use explicit `force == true` param.
-   [+] Add `count` procs to count rows without fetching them.
-   [t] Remove unused import from `sqlite/trows.nim`.


## 2.2.5 (March 23, 2021)

-   [+] Add `onDelete` pragma that lets add `ON DELETE` constraints to foreign keys.
-   [r] Improve formatting of import statements: use `std/` notation.


## 2.2.4 (March 21, 2021)

-   [+] `NotFoundError` exception is raised instead of `KeyError` if a record is not found.
-   [f] Fix issue with objects with `none Model` fields failing to be used as containers to select records into (see [#103](https://github.com/moigagoo/norm/issues/103)).
-   [f] Allow objects to be inserted multiple times. The `id` is updated with each insertion (see [#104](https://github.com/moigagoo/norm/issues/104)).
-   [t] Added tests for record not found case.
-   [t] Added tests for `none Model` container fields.


## 2.2.3 (February 20, 2021)

-   [+] `id` is now `int64` instead of `int` to produce a DB type in Postgres that doesn't depend on the processor architecture of a particular computer running the code.
-   [+] Add granular convertors for `int16`, `int32`, and `int64` in Postgres.
-   [+] Add granular convertors for `float32` and `float64` in Postgres.
-   [+] Add type `StringOfCap[static n]` that is converted to `VARCHAR(n)` in Postgres.
-   [+] Add type `PaddedStringOfCap[static n]` that is converted to `CHAR(n)` in Postgres.
-   [t] Remove redundant environment variable usage from `tdbtypes` tests.


## 2.2.2 (November 19, 2020)

-   [f] Fix `ProveInit` warning.


## 2.2.1 (November 10, 2020)

-   [+] Added `fk` pragma that allows to manually declare a `SomeInteger` field of `Model` as a foreign key.

    Pragma value must be a `Model`. The foreign key will reference the referenced model's `id` field.

-   [t] Reorganized tests into folders.
-   [t] Switch from vanilla `nimble test` to testament.
-   [t] Added missing tests for `NULL` foreign keys in Postgres.
-   [t] Cleaned up redundant imports and consts.


## 2.2.0 (October 26, 2020)

-   [!][f][t] The way `JOIN` statements are generated has been changed competely. The previous algorithm was just wrong, it didn't work with models that that multiple FKs to the same model or when the same model was referenced from the root model and any of its `Model` fields or their `Model` fields.

Long story short, the old algorithm would rely on table names with no regard for whether the table is a foreign key. That means that, if you had the same table referenced with two different fields, the `JOIN` statement would make no difference between them, which led to invalid selections (see `[#82](https://github.com/moigagoo/norm/issues/82)).

The new algorithm adds alias for each joined table. The alias is named after the model field that points to the table. Compare [tests/tmodel.nim](https://github.com/moigagoo/norm/blob/2.2.0/tests/tmodel.nim) before and after the change:

    # Old way:
    test "Join groups":
      let
        toy = newToy(123.45)
        pet = newPet("cat", toy)
        person = newPerson("Alice", pet)

      check person. joinGroups == @[
        (""""Pet"""", """"Person".pet""", """"Pet".id"""),
        (""""Toy"""", """"Pet".favToy""", """"Toy".id""")
      ]
      # produces the following `JOIN` statement:
      # `JOIN "Pet" ON "Person".pet = "Pet".id JOIN "Toy" ON "Pet".favToy = "Toy".id`

    # New way:
    test "Join groups":
      let
        toy = newToy(123.45)
        pet = newPet("cat", toy)
        person = newPerson("Alice", pet)

      check person.joinGroups == @[
        (""""Pet"""", """"pet"""", """"Person".pet""", """"pet".id"""),
        (""""Toy"""", """"pet_favToy"""", """"pet".favToy""", """"pet_favToy".id""")
      ]
      # produces the following `JOIN` statement:
      # `JOIN "Pet" AS "pet" ON "Person".pet = "pet".id JOIN "Toy" AS "pet_favToy" ON "pet".favToy = "pet_favToy".id`

**With the change in the algorithm, the way `select` conditions must be composed has changed.** Here's an example from the tests to illustrate this change ([tests/tpostgresrows.nim](https://github.com/moigagoo/norm/blob/2.2.0/tests/tpostgresrows.nim)):

    # Old way:
    test "Get rows, nested models":
      var
        inpPersons = @[
          newPerson("Alice", newPet("cat", newToy(123.45))),
          newPerson("Bob", newPet("dog", newToy(456.78))),
          newPerson("Charlie", newPet("frog", newToy(99.99))),
        ]
        outPersons = @[newPerson()]

      for inpPerson in inpPersons.mitems:
        dbConn.insert(inpPerson)

      # We're querying by `"Toy".price` as if it weren't `favToy` field of `pet` field of `Person` model:
      dbConn.select(outPersons, """"Toy".price > $1""", 100.00)

      check outPersons === inpPersons[0..^2]

    # New way:
    test "Get rows, nested models":
      var
        inpPersons = @[
          newPerson("Alice", newPet("cat", newToy(123.45))),
          newPerson("Bob", newPet("dog", newToy(456.78))),
          newPerson("Charlie", newPet("frog", newToy(99.99))),
        ]
        outPersons = @[newPerson()]

      for inpPerson in inpPersons.mitems:
        dbConn.insert(inpPerson)

      # Querying by `"pet_favToy".price` to indicate that we want to match specifically by `Person.pet.favToy`:
      dbConn.select(outPersons, """"pet_favToy".price > $1""", 100.00)

      check outPersons === inpPersons[0..^2]

-   [f][t] Fix [#79](https://github.com/moigagoo/norm/issues/79). `NULL` foreign keys are not omitted in selects anymore if the container objects is `some Model`.

-   [+] Add `selectAll` procs to select all rows without condition (see [#85](https://github.com/moigagoo/norm/issues/85)).

-   [r] Require Nim version >= 1.4.0.

-   [r] Update Nim version to 1.4.0 in Dockerfile.

-   [+] Hide logging behind `normDebug` compilation flag to improve runtime performance.

-   [+] Add `unique` pragma to add `UNIQUE` constaints to fields.


## 2.1.5 (September 8, 2020)

-   [+] Export private `dbValue`, and `to` procs in public modules.


## 2.1.4 (August 14, 2020)

-   [+] Add `dropDb` procs.


## 2.1.3 (August 13, 2020)

-   [f] Fix relation triangle with more deeply nested relations.


## 2.1.2 (August 12, 2020)

-   [f] Fix `select` for models that relate to two models that are related with each other as well.


## 2.1.1 (July 10, 2020)

-   [r] Add missing docstrings for `getDb` and `withDb`.


## 2.1.0 (July 10, 2020)

-   [+] Add `getDb` and `withDb` sugars to get DB configuration from environment variables `DB_HOST`, `DB_USER`, `DB_PASS`, and `DB_NAME`.


## 2.0.1 (June 24, 2020)

-   [f] Replace func with proc in dbtypes since `to` can have side effects.


## 2.0.0 (June 22, 2020)

Rewritten from scratch. **Backward compatibility has been completely broken.**

Most noticeable changes are:

-   DB procs work only with model instances and never with model types.
-   DB procs mutate objects in-place. To create new instances, use `dup`.
-   Models are ref types instead of value types.
-   Model objects are defined by being inherited from `Model` and not by being defined under `db` block.
-   DB procs now take database connection as the first argument.
-   Foreign keys are created automatically.
-   N+1 problem has been solved.
-   Most pragmas are gone, resulting in less customizability but simpler API.
-   Adding custom converters now means adding procs and not putting expressions in pragmas, which was very fragile.


## 1.1.3 (May 11, 2020)

-   [f] Fix [#69](https://github.com/moigagoo/norm/issues/69): `table` pragma is now respected as it should despite being deprecated.


## 1.1.2 (March 13, 2020)

-   [f] Fix [#63](https://github.com/moigagoo/norm/issues/63): foreign key boilerplate code is now correctly injected into exported type definitions.


## 1.1.1 (March 13, 2020)

-   [+] Add `insertId` proc that takes an immutable object and inserts it as a record to the DB. The inserted record ID is returned. The object `id` field is **not** updated.

-   [+] Automatically generate foreign key boilerplate for models defined under the same `type` section. See examples in [tests/tpostgres.nim](https://github.com/moigagoo/norm/blob/1.1.1/tests/tpostgres.nim) and [tests/tsqlite.nim](https://github.com/moigagoo/norm/blob/1.1.1/tests/tsqlite.nim).


## 1.1.0 (January 27, 2020)

-   [!] Deprecate `notNull` pragma. `NOT NULL` is the default for all types except `Option`.

    To set `NOT NULL` constraint for custom DB types, add it directly to `dbType`, e.g. `{.dbType: "INTEGER NOT NULL".}`.

-   [!] Rename pragma `table` to `dbTable`.
-   [!] Deprecate `default` pragma. Default values are added to tables by default.
-   [!][+] Rewrite PostgreSQL backend to use [ndb](https://github.com/xzfc/ndb.nim)_, which adds `NULL` support via `Option` type similarly to SQLite backend.
-   [+] Add `transaction` macro to run multiple commands in a transaction and `rollback` proc to safely interrupt a transaction.
-   [+] Add `createTable` and `dropTable`.
-   [+] SQLite: Add means to write migrations: `addColumn`, `dropUnusedColumns`, `renameColumnFrom`, and `renameTableFrom`.
-   [+] PostgreSQL: Add means to write migrations: `addColumn`, `dropColumns`, `dropUnusedColumns`, `renameColumnFrom`, and `renameTableFrom`.
-   [+] Add support for `int64` field type.
-   [+] Add `getAll` template to get all records without limit or offset.
-   [r] Rewrite table schema generation so that schemas are generated from typed nodes rather than untyped modes.
-   [f] Fix "unreachable statement" compile error for certain SQLite use cases.


## 1.0.17 (September 12, 2019)

-   [f] Fixed table schema generation for `Positive` and `Natural` types: they used to be stored as `TEXT`, now they are stored as `INTEGER`. Also, fixed [#28](https://github.com/moigagoo/norm/issues/28).


## 1.0.16 (September 11, 2019)

-   [f] Added missing `strutils` export to eliminate `Error: undeclared identifier: '%'` and fix [#27](https://github.com/moigagoo/norm/issues/27).
-   [r] `genTableSchema` now returns `SqlQuery` instead of `string` to be in line with the other `gen*` procs.


## 1.0.15 (September 06, 2019)

-   [+] Add `dbTypes` macro to mark existing type sections to be usable in DB schema generation.
-   [+] Add `dbFromTypes` macro to define DB schema from existing types. This is an alternative to defining the entire schema under `db` macro.
-   [f] PostgreSQL: `times.Datetime` are now explicitly stored in UTC timezone.
-   [r] Move row-object conversion and SQL query generation into backend-specific submodules: `sqlite/rowutils.nim`, `sqlite/sqlgen.nim`, `postgres/rowutils.nim`, `postgres/sqlgen.nim`.
-   [r] Move procs to inject `id` field in type definitions into a separate module `typedefutils.nim`.


## 1.0.14 (August 21, 2019)

-   [+] PostgreSQL: Support `bool` type.
-   [+] SQLite, PostgreSQL: Support `times.DateTime` type.


## 1.0.13 (August 16, 2019)

-   [f] SQLite: `TEXT` type fields would be created for `bool` type object fields, whereas `INTEGER` should have been used.


## 1.0.12 (August 15, 2019)

-   [!] `formatIt` expression must evaluate to `DbValue`, implicit conversion has been removed.
-   [+] SQLite: Added boolean type conversion. Nim bools are stored as 1 and 0 in SQLite. SQLite's 0's are converted to `false`, any other number—to `true`.


## 1.0.11 (June 15, 2019)

-   [!] SQLite: Switch to [ndb](https://github.com/xzfc/ndb.nim)_.
-   [!] SQLite: Non-`Option` non-custom types are `NOT NULL` by default.
-   [+] SQLite: Support inserting and retrieving `NULL` values with `Option` types.
-   [+] SQLite, PostgreSQL: Add `withCustomDb` to run DB procs on a non-default DB (i.e. not the one defined in `db` declaration).
-   [r] Replace `type` with `typedesc` and `typeof` where it is not a type definition.


## 1.0.10 (June 6, 2019)

-   [r] Rename `getUpdateQuery` to `genUpdateQuery`.
-   [f] Fix compatibility with nim 0.20.0.


## 1.0.9 (May 9, 2019)

-   [!] Change signatures for `getMany` and `getOne`: instead of `where` and `orderBy` args there's a single `cond` arg.
-   [+] Add `params` arg to `getMany` and `getone` to allow safe value insertion in SQL queries.
-   [+] Add ```getOne(cond: string, params: varargs[string, `$`])``` procs to query a single record by condition.


## 1.0.8 (April 30, 2019)

-   [+] SQLite: Add `onUpdate` and `onDelete` pragmas.
-   [+] SQLite: Add `unique` pragma.
-   [f] SQLite: Add support for multiple foreign keys.
-   [f] SQLite: Enable foreign keys for all connections.
-   [t] Add tests for multiple foreign keys.


## 1.0.7 (March 21, 2019)

-   [+] Add `orderBy` argument to `getMany` procs.


## 1.0.6 (March 21, 2019)

-   [+] Log all generated SQL statements as debug level logs.


## 1.0.5 (March 18, 2019)

-   [+] Do not require `chronicles` package.


## 1.0.4 (March 3, 2019)

-   [+] Add `where` lookup to `getMany` procs.


## 1.0.3 (March 2, 2019)

-   [r] objutils: Rename `[]` field accessor to `dot` to avoid collisions with `tables` module.


## 1.0.2 (March 1, 2019)

-   [!] Procs defined in `db` macro are now passed as is to the resulting code and are not forced inside `withdb` template.
-   [+] Allow to override column names for fields with `dbCol` pragma.


## 1.0.1 (February 28, 2019)

-   [+] Respect custom field parsers and formatters.
-   [+] rowutils: respect `ro` pragma in `toRow` proc.
-   [+] objutils: respect `ro` pragma in `fieldnames` proc.
-   [t] Type conversion: fix issue with incorrect conversion of field named `name`.


## 1.0.0 (February 27, 2019)

-   🎉 initial release.
