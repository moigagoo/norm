#   Reference Guide

Listed below are the procs that build up a CRUD for manipulating tables and rows in Norm.

These procs are available in `withDb` and `withCustomDb` macros regardless of the backend used.


##  Setting Up Database

-   `createTables(force = false)`

    Generate and execute an SQL database schema from a type section.

    Run once to initialize the DB.

    `force=true` prepends `DROP TABLE IF EXISTS` for all genereated tables.

    Relevant tests:

    -   https://github.com/moigagoo/norm/develop/tests/tsqlite.nim#49
    -   https://github.com/moigagoo/norm/develop/tests/tpostgres.nim#49


##  Writing Migrations

!!! note
    Although Norm provides the means to write and apply migrations manually, the plan is to develop a tool to generate migrations from model diffs and apply them with the option to rollback.

    The development hasn't started yet but I think I already have a vision and a nice name for it.

-   `createTable(T: typedesc, force = false)`

    Generate and execute an SQL table schema from a type definition. Column schemas are generated from Nim object field definitions. Basic types are mapped automatically. For custom types, _parser_ and _formatter_ must be provided.

    Use to update the DB schema after adding new models.

    `force=true` prepends `DROP TABLE IF EXISTS` to the generated query.

    Relevant tests:

    -   https://github.com/moigagoo/norm/blob/develop/tests/tsqlitemigrate.nim#L35
    -   https://github.com/moigagoo/norm/blob/develop/tests/tpostgresmigrate.nim#L50

-   `addColumn(field: typedesc)`

    Generate and execute an SQL query to add a column to an existing table.

    Use to create columns after adding new fields to existing models.

    `field` should point to the model field for which the column is to be created, e.g. `Pet.age`.

    Relevant tests:

    -   https://github.com/moigagoo/norm/blob/develop/tests/tsqlitemigrate.nim#L44
    -   https://github.com/moigagoo/norm/blob/develop/tests/tpostgresmigrate.nim#L61

-   `dropUnusedColumns(T: typedesc)`

    Recreate the table from a model, losing unmatching columns in the process. This involves creating a temporary table and copying the data there, then dropping the original table and renaming the temporary one to the original one's name.

    Use to clean up DB after removing a field from a model.

    Relevant tests:

    -   https://github.com/moigagoo/norm/blob/develop/tests/tsqlitemigrate.nim#L57
    -   https://github.com/moigagoo/norm/blob/develop/tests/tpostgresmigrate.nim#L79

-   `renameColumnFrom(field: typedesc, oldName: string)`.

    Rename a DB column to match the model field. Provide `oldName` to tell Norm which column you are renaming. This has to be done manually since there's no way to guess the programmer's intetion when they rename a model field: is it to rename the underlying DB column or to remove the old column and create a new one instead?

    Use this proc to rename a column. To replace a column, use `addColumn` with conjunction with `dropUnusedColumns`.

    Relevant tests:

    -   https://github.com/moigagoo/norm/blob/develop/tests/tsqlitemigrate.nim#L72
    -   https://github.com/moigagoo/norm/blob/develop/tests/tsqlitemigrate.nim#L95
    -   https://github.com/moigagoo/norm/blob/develop/tests/tpostgresmigrate.nim#L89
    -   https://github.com/moigagoo/norm/blob/develop/tests/tpostgresmigrate.nim#L106

-   `renameTableFrom(T: typedesc, oldName: string)`

    Rename a DB table to match the model name. The old table name must be provided explicitly because when the DB table name for a model changes, there's no way to guess which existing table used to match this model.

    Use after renaming a model or changing its `dbTable` pragma value.

    Relevant tests:

    -   https://github.com/moigagoo/norm/blob/develop/tests/tsqlitemigrate.nim#L85
    -   https://github.com/moigagoo/norm/blob/develop/tests/tpostgresmigrate.nim#L98



### Delete

- `dropTable(T: typedesc)`
- `dropTables(T: typedesc)`


## Manipulating Rows

### Create

- `insert`


### Read

- `getOne`
- `getMany`
- `getAll`


### Updates

-   `update`


### Delete

-   `delete`

## Transactions

`transation`
