# Changelog

-   [!]—backward incompatible change
-   [+]—new feature
-   [f]—bugfix
-   [r]—refactoring
-   [t]—test suite improvement


## 1.0.14 (WIP)

-   [+] PostgreSQL: Support `bool` type.
-   [+] SQLite, PostgreSQL: Support `times.DateTime` type.


## 1.0.13 (August 16, 2019)

-   [f] SQLite: `TEXT` type fields would be created for `bool` type object fields, whereas `INTEGER` should have been used.


## 1.0.12 (August 15, 2019)

-   [!] `formatIt` expression must evaluate to `DbValue`, implicit conversion has been removed.
-   [+] SQLite: Added boolean type conversion. Nim bools are stored as 1 and 0 in SQLite. SQLite's 0's are converted to `false`, any other number—to `true`.


## 1.0.11 (June 15, 2019)

-   [!] SQLite: Switch to [ndb](https://github.com/xzfc/ndb.nim).
-   [!] SQLite: Non-`Option` non-custom types are `NOT NULL` by default.
-   [+] SQLite: Support inserting and retreiving `NULL` values with `Option` types.
-   [+] SQLite, PostgreSQL: Add `withCustomDb` to run DB procs on a non-default DB (i.e. not the one defined in `db` definition).
-   [r] Replace `type` with `typedesc` and `typeof` where it is not a type definition.


## 1.0.10 (June 6, 2019)

-   [r] Rename `getUpdateQuery` to `genUpdateQuery`.
-   [f] Fix compatibility with Nim 0.20.0.


## 1.0.9 (May 8, 2019)

-   [!] Change signatures for `getMany` and `getOne`: instead of `where` and `orderBy` args there's a single `cond` arg.
-   [+] Add `params` arg to `getMany` and `getOne` to allow safe value insertion in SQL queries.
-   [+] Add ```getOne(cond: string, params: varargs[string, `$`])``` procs to query a single record by condition.


## 1.0.8 (April 30, 2019)

-   [+] SQLite: Add `{.onUpdate}` and `{.onDelete.}` pragmas (thanks to @alaviss).
-   [+] SQLite: Add `unique` pragma.
-   [f] SQLite: Add support for multiple foreign keys (thanks to @alaviss).
-   [f] SQLite: Enable foreign keys for all connections (thanks to @alaviss).
-   [t] Add tests for multiple foreign keys.


## 1.0.7 (March 21, 2019)

-   [+] Add ``orderBy`` argument to ``getMany`` procs.


## 1.0.6 (March 21, 2019)

-   [+] Log all generated SQL statements as debug level logs.


## 1.0.5 (March 18, 2019)

-   [+] Do not require ``chronicles`` package.


## 1.0.4 (March 3, 2019)

-   [+] Add ``WHERE`` lookup to ``getMany`` procs.


## 1.0.3 (March 2, 2019)

-   [r] Objutils: Rename ``[]`` field accessor to ``dot`` to avoid collisions with ``tables`` module.


## 1.0.2 (March 1, 2019)

-   [!] Procs defined in ``db`` macro are now passed as is to the resulting code and are not forced inside ``withDb`` template.
-   [+] Allow to override column names for fields with ``dbCol`` pragma.


## 1.0.1 (February 28, 2019)

-   [+] Respect custom field parsers and formatters.
-   [+] Rowutils: Respect ``ro`` pragma in ``toRow`` proc.
-   [+] Objutils: Respect ``ro`` pragma in ``fieldNames`` proc.
-   [t] Type conversion: Fix issue with incorrect conversion of field named ``name``.


## 1.0.0 (February 27, 2019)

-   🎉 Initial release.
