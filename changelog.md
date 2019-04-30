# Changelog

## 1.0.8

-   SQLite: Add `{.onUpdate}` and `{.onDelete.}` pragmas (thanks to @alaviss).
-   SQLite: Add support for multiple foreign keys (thanks to @alaviss).
-   SQLite: Enable foreign keys for all connections (thanks to @alaviss).
-   SQLite: Add `unique` pragma.
-   Add tests for multiple foreign keys.


## 1.0.7

-   Add ``orderBy`` argument to ``getMany`` procs.


## 1.0.6

-   Log all generated SQL statements as debug level logs.


## 1.0.5

-   Do not require ``chronicles`` package.


## 1.0.4

-   Add ``WHERE`` lookup to ``getMany`` procs.


## 1.0.3

-   Objutils: Rename ``[]`` field accessor to ``dot`` to avoid collisions with ``tables`` module.


## 1.0.2

-   Procs defined in ``db`` macro are now passed as is to the resulting code and are not forced inside ``withDb`` template.
-   Allow to override column names for fields with ``dbCol`` pragma.


## 1.0.1

-   Respect custom field parsers and formatters.
-   Type conversion: Fix issue with incorrect conversion of field named ``name``.
-   Rowutils: Respect ``ro`` pragma in ``toRow`` proc.
-   Objutils: Respect ``ro`` pragma in ``fieldNames`` proc.


## 1.0.0

-   Initial release.
