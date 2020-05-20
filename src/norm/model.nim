import macros
import strutils

import norm/private/dot
import norm/pragmas


type
  Model* = object of RootObj
    id* {.pk, ro.}: int


proc table*(T: typedesc[Model]): string =
  ## Get table name for ``norm.Model``, which is the type name in single quotes.

  "'$#'" % $T

proc table*[T: Model](obj: T): string =
  T.table

proc col*[T: Model](obj: T, fld: string): string =
  ## Get column name for a ``norm.Model`` field, which is the field name in single quotes.

  fld

proc fCol*[T: Model](obj: T, fld: string): string =
  ## Get fully qualified column name with the table name: ``table.col``.

  "'$#'.$#" % [$T, fld]

proc cols*[T: Model](obj: T, force = false): seq[string] =
  ##[ Get columns for ``norm.Model`` instance.

  If ``force`` is ``true``, fields with ``norm.pragmas.ro`` are included.
  ]##

  for fld, val in obj.fieldPairs:
    if force or not obj.dot(fld).hasCustomPragma(ro):
      result.add obj.col(fld)

proc rCols*[T: Model](obj: T): seq[string] =
  ## Recursively get columns for ``norm.Model`` instance and its ``norm.Model`` fields.

  for fld, val in obj.fieldPairs:
    when val is Model:
      result.add val.rCols
    else:
      result.add obj.col(fld)

proc rfCols*[T: Model](obj: T): seq[string] =
  ## Recursively get fully qualified column names for ``norm.Model`` instance and its ``norm.Model`` fields.

  for fld, val in obj.fieldPairs:
    when val is Model:
      result.add val.rfCols
    else:
      result.add obj.fCol(fld)

proc joinGroups*[T: Model](obj: T): seq[tuple[tbl, lFld, rFld: string]] =
  ##[ For each ``norm.Model`` field of ``norm.Model`` instance, get:
  - table name for the field type
  - full column name for the field
  - full column name for "id" field of the field type

  Used to construct ``JOIN`` statements: ``JOIN {tbl} ON {lFld} = {rFld}``
  ]##

  for fld, val in obj.fieldPairs:
    when val is Model:
      result.add (tbl: val.table, lFld: obj.fCol(fld), rFld: val.fCol("id"))
      result.add val.joinGroups
