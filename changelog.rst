*********
Changelog
*********

-   [!]—backward incompatible change
-   [+]—new feature
-   [f]—bugfix
-   [r]—refactoring
-   [t]—test suite improvement


2.1.0 (WIP)
===========

-   [+] Add ``getDb`` and ``withDb`` sugars to get DB configuration from environment variables ``DB_HOST``, ``DB_USER``, ``DB_PASS``, and ``DB_NAME``.


2.0.1 (June 24, 2020)
=====================

-   [f] Replace func with proc in dbtypes since ``to`` can have side effects.


2.0.0 (June 22, 2020)
=====================

Rewritten from scratch. **Backward compatibility has been completely broken.**

Most noticeable changes are:

-   DB procs work only with model instances and never with model types.
-   DB procs mutate objects in-place. To create new instances, use ``dup``.
-   Models are ref types instead of value types.
-   Model objects are defined by being inherited from ``Model`` and not by being defined under ``db`` block.
-   DB procs now take database connection as the first argument.
-   Foreign keys are created automatically.
-   N+1 problem has been solved.
-   Most pragmas are gone, resulting in less customizability but simpler API.
-   Adding custom converters now means adding procs and not putting expressions in pragmas, which was very fragile.


1.1.3 (May 11, 2020)
====================

-   [f] Fix `#69 <https://github.com/moigagoo/norm/issues/69>`__: `table` pragma is now respected as it should despite being deprecated.


1.1.2 (March 13, 2020)
======================

-   [f] Fix `#63 <https://github.com/moigagoo/norm/issues/63>`__: foreign key boilerplate code is now correctly injected into exported type definitions.


1.1.1 (March 13, 2020)
======================

-   [+] Add ``insertId`` proc that takes an immutable object and inserts it as a record to the DB. The inserted record ID is returned. The object ``id`` field is **not** updated.

-   [+] Automatically generate foreign key boilerplate for models defined under the same ``type`` section. See examples in `tests/tpostgres.nim <https://github.com/moigagoo/norm/blob/develop/tests/tpostgres.nim>`__ and `tests/tsqlite.nim <https://github.com/moigagoo/norm/blob/develop/tests/tsqlite.nim>`__.


1.1.0 (January 27, 2020)
========================

-   [!] Deprecate ``notNull`` pragma. ``NOT NULL`` is the default for all types except ``Option``.

    To set ``NOT NULL`` constraint for custom DB types, add it directly to ``dbType``, e.g. ``{.dbType: "INTEGER NOT NULL".}``.

-   [!] Rename pragma ``table`` to ``dbTable``.
-   [!] Deprecate ``default`` pragma. Default values are added to tables by default.
-   [!][+] Rewrite PostgreSQL backend to use `ndb <https://github.com/xzfc/ndb.nim>`__, which adds ``NULL`` support via ``Option`` type similarly to SQLite backend.
-   [+] Add ``transaction`` macro to run multiple commands in a transaction and ``rollback`` proc to safely interrupt a transaction.
-   [+] Add ``createTable`` and ``dropTable``.
-   [+] SQLite: Add means to write migrations: ``addColumn``, ``dropUnusedColumns``, ``renameColumnFrom``, and ``renameTableFrom``.
-   [+] PostgreSQL: Add means to write migrations: ``addColumn``, ``dropColumns``, ``dropUnusedColumns``, ``renameColumnFrom``, and ``renameTableFrom``.
-   [+] Add support for ``int64`` field type.
-   [+] Add ``getAll`` template to get all records without limit or offset.
-   [r] Rewrite table schema generation so that schemas are generated from typed nodes rather than untyped modes.
-   [f] Fix "unreachable statement" compile error for certain SQLite use cases.


1.0.17 (September 12, 2019)
===========================

-   [f] Fixed table schema generation for ``Positive`` and ``Natural`` types: they used to be stored as ``TEXT``, now they are stored as ``INTEGER``. Also, fixed `#28 <https://github.com/moigagoo/norm/issues/28>`__.


1.0.16 (September 11, 2019)
===========================

-   [f] Added missing ``strutils`` export to eliminate ``Error: undeclared identifier: '%'`` and fix `#27 <https://github.com/moigagoo/norm/issues/27>`__.
-   [r] ``genTableSchema`` now returns ``SqlQuery`` instead of ``string`` to be in line with the other ``gen*`` procs.


1.0.15 (September 06, 2019)
===========================

-   [+] Add ``dbTypes`` macro to mark existing type sections to be usable in DB schema generation.
-   [+] Add ``dbFromTypes`` macro to define DB schema from existing types. This is an alternative to defining the entire schema under ``db`` macro.
-   [f] PostgreSQL: ``times.Datetime`` are now explicitly stored in UTC timezone.
-   [r] Move row-object conversion and SQL query generation into backend-specific submodules: ``sqlite/rowutils.nim``, ``sqlite/sqlgen.nim``, ``postgres/rowutils.nim``, ``postgres/sqlgen.nim``.
-   [r] Move procs to inject ``id`` field in type definitions into a separate module ``typedefutils.nim``.


1.0.14 (August 21, 2019)
========================

-   [+] PostgreSQL: Support ``bool`` type.
-   [+] SQLite, PostgreSQL: Support ``times.DateTime`` type.


1.0.13 (August 16, 2019)
========================

-   [f] SQLite: ``TEXT`` type fields would be created for ``bool`` type object fields, whereas ``INTEGER`` should have been used.


1.0.12 (August 15, 2019)
========================

-   [!] ``formatIt`` expression must evaluate to ``DbValue``, implicit conversion has been removed.
-   [+] SQLite: Added boolean type conversion. Nim bools are stored as 1 and 0 in SQLite. SQLite's 0's are converted to ``false``, any other number—to ``true``.


1.0.11 (june 15, 2019)
======================

-   [!] SQLite: Switch to `ndb <https://github.com/xzfc/ndb.nim>`__.
-   [!] SQLite: Non-``Option`` non-custom types are ``NOT NULL`` by default.
-   [+] SQLite: Support inserting and retreiving ``NULL`` values with ``Option`` types.
-   [+] SQLite, PostgreSQL: Add ``withCustomDb`` to run DB procs on a non-default DB (i.e. not the one defined in ``db`` declaration).
-   [r] Replace ``type`` with ``typedesc`` and ``typeof`` where it is not a type definition.


1.0.10 (june 6, 2019)
=====================

-   [r] Rename ``getUpdateQuery`` to ``genUpdateQuery``.
-   [f] Fix compatibility with nim 0.20.0.


1.0.9 (may 8, 2019)
===================

-   [!] Change signatures for ``getMany`` and ``getOne``: instead of ``where`` and ``orderBy`` args there's a single ``cond`` arg.
-   [+] Add ``params`` arg to ``getMany`` and ``getone`` to allow safe value insertion in SQL queries.
-   [+] Add ``getOne(cond: string, params: varargs[string, `$`])`` procs to query a single record by condition.


1.0.8 (april 30, 2019)
======================

-   [+] SQLite: Add ``onUpdate`` and `onDelete` pragmas.
-   [+] SQLite: Add ``unique`` pragma.
-   [f] SQLite: Add support for multiple foreign keys.
-   [f] SQLite: Enable foreign keys for all connections.
-   [t] Add tests for multiple foreign keys.


1.0.7 (march 21, 2019)
======================

-   [+] Add ``orderBy`` argument to ``getMany`` procs.


1.0.6 (march 21, 2019)
======================

-   [+] Log all generated SQL statements as debug level logs.


1.0.5 (march 18, 2019)
======================

-   [+] Do not require ``chronicles`` package.


1.0.4 (march 3, 2019)
=====================

-   [+] Add ``where`` lookup to ``getMany`` procs.


1.0.3 (march 2, 2019)
=====================

-   [r] objutils: Rename ``[]`` field accessor to ``dot`` to avoid collisions with ``tables`` module.


1.0.2 (march 1, 2019)
=====================

-   [!] Procs defined in ``db`` macro are now passed as is to the resulting code and are not forced inside ``withdb`` template.
-   [+] Allow to override column names for fields with ``dbCol`` pragma.


1.0.1 (february 28, 2019)
=========================

-   [+] Respect custom field parsers and formatters.
-   [+] rowutils: respect ``ro`` pragma in ``toRow`` proc.
-   [+] objutils: respect ``ro`` pragma in ``fieldnames`` proc.
-   [t] Type conversion: fix issue with incorrect conversion of field named ``name``.


1.0.0 (february 27, 2019)
=========================

-   🎉 initial release.
