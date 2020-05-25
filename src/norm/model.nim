import macros
import strutils

import private/dot
import pragmas


type
  Model* = object of RootObj
    ##[ Base type for models.

    ``id`` corresponds to row id in DB. **Updated automatically, do not update manually!**
    ]##

    id* {.pk, ro.}: int


proc table*(T: typedesc[Model]): string =
  ## Get table name for `Model <#Model>`_, which is the type name in single quotes.

  '"' & $T & '"'

proc col*[T: Model](obj: T, fld: string): string =
  ## Get column name for a `Model`_ field, which is just the field name.

  fld

proc fCol*[T: Model](obj: T, fld: string): string =
  ## Get fully qualified column name with the table name: ``table.col``.

  "$#.$#" % [T.table, obj.col(fld)]

proc cols*[T: Model](obj: T, force = false): seq[string] =
  ##[ Get columns for `Model`_ instance.

  If ``force`` is ``true``, fields with `ro <pragmas.html#ro.t>`_ are included.
  ]##

  for fld, val in obj.fieldPairs:
    if force or not obj.dot(fld).hasCustomPragma(ro):
      result.add obj.col(fld)

proc rCols*[T: Model](obj: T): seq[string] =
  ## Recursively get columns for `Model`_ instance and its `Model`_ fields.

  for fld, val in obj.fieldPairs:
    when val is Model:
      result.add val.rCols
    else:
      result.add obj.col(fld)

proc rfCols*[T: Model](obj: T): seq[string] =
  ## Recursively get fully qualified column names for `Model`_ instance and its `Model`_ fields.

  for fld, val in obj.fieldPairs:
    when val is Model:
      result.add val.rfCols
    else:
      result.add obj.fCol(fld)

proc joinGroups*[T: Model](obj: T): seq[tuple[tbl, lFld, rFld: string]] =
  ##[ For each `Model`_ field of `Model`_ instance, get:
  - table name for the field type
  - full column name for the field
  - full column name for ``id`` field of the field type

  Used to construct ``JOIN`` statements: ``JOIN {tbl} ON {lFld} = {rFld}``
  ]##

  for fld, val in obj.fieldPairs:
    when val is Model:
      result.add (tbl: typeof(val).table, lFld: obj.fCol(fld), rFld: val.fCol("id"))
      result.add val.joinGroups
