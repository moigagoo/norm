# Changelog

-   ❗—backward incompatible API change
-   ➕—new feature
-   👌—bugfix
-   🔨—refactoring
-   ✅—test suite improvement


## 1.0.10

-   🔨 Rename `getUpdateQuery` to `genUpdateQuery`.
-   👌 Fix compatibility with Nim 0.20.0.


## 1.0.9

-   ❗ Change signatures for `getMany` and `getOne`: instead of `where` and `orderBy` args there's a single `cond` arg.
-   ➕ Add `params` arg to `getMany` and `getOne` to allow safe value insertion in SQL queries.
-   ➕ Add ```getOne(cond: string, params: varargs[string, `$`])``` procs to query a single record by condition.


## 1.0.8

-   ➕ SQLite: Add `{.onUpdate}` and `{.onDelete.}` pragmas (thanks to @alaviss).
-   ➕ SQLite: Add `unique` pragma.
-   👌 SQLite: Add support for multiple foreign keys (thanks to @alaviss).
-   👌 SQLite: Enable foreign keys for all connections (thanks to @alaviss).
-   ✅ Add tests for multiple foreign keys.


## 1.0.7

-   ➕ Add ``orderBy`` argument to ``getMany`` procs.


## 1.0.6

-   ➕ Log all generated SQL statements as debug level logs.


## 1.0.5

-   ➕ Do not require ``chronicles`` package.


## 1.0.4

-   ➕ Add ``WHERE`` lookup to ``getMany`` procs.


## 1.0.3

-   🔨 Objutils: Rename ``[]`` field accessor to ``dot`` to avoid collisions with ``tables`` module.


## 1.0.2

-   ❗ Procs defined in ``db`` macro are now passed as is to the resulting code and are not forced inside ``withDb`` template.
-   ➕ Allow to override column names for fields with ``dbCol`` pragma.


## 1.0.1

-   ➕ Respect custom field parsers and formatters.
-   ➕ Rowutils: Respect ``ro`` pragma in ``toRow`` proc.
-   ➕ Objutils: Respect ``ro`` pragma in ``fieldNames`` proc.
-   ✅ Type conversion: Fix issue with incorrect conversion of field named ``name``.


## 1.0.0

-   🎉 Initial release.
