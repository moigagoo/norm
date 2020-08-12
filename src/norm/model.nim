import macros
import options
import strutils

import private/dot
import pragmas


type
  Model* = ref object of RootObj
    ##[ Base type for models.

    ``id`` corresponds to row id in DB. **Updated automatically, do not update manually!**
    ]##

    id* {.pk, ro.}: int


func isModel*[T: Model](val: T): bool = true

func isModel*[T: Model](val: Option[T]): bool = true

func isModel*[T](val: T): bool = false

func model*[T: Model](val: T): Option[T] = some val

func model*[T: Model](val: Option[T]): Option[T] = val

func model*[T](val: T): Option[Model] =
  ## This is never called and exists only to please the compiler.

  none Model

func table*(T: typedesc[Model]): string =
  ## Get table name for `Model <#Model>`_, which is the type name in single quotes.

  '"' & $T & '"'

func col*(T: typedesc[Model], fld: string): string =
  ## Get column name for a `Model`_ field, which is just the field name.

  fld

func col*[T: Model](obj: T, fld: string): string =
  T.col(fld)

func fCol*[T: Model](obj: T, fld: string): string =
  ## Get fully qualified column name with the table name: ``table.col``.

  "$#.$#" % [T.table, obj.col(fld)]

func cols*[T: Model](obj: T, force = false): seq[string] =
  ##[ Get columns for `Model`_ instance.

  If ``force`` is ``true``, fields with `ro <pragmas.html#ro.t>`_ are included.
  ]##

  for fld, val in obj[].fieldPairs:
    if force or not obj.dot(fld).hasCustomPragma(ro):
      result.add obj.col(fld)

func rfCols*[T: Model](obj: T): seq[string] =
  ## Recursively get fully qualified column names for `Model`_ instance and its `Model`_ fields.

  for fld, val in obj[].fieldPairs:
    if val.isModel:
      if val.model.isSome:
        result.add (get val.model).rfCols
    else:
      result.add obj.fCol(fld)

func joinGroups[T: Model](obj: T, tbls: var seq[string]): seq[tuple[tbl, lFld, rFld: string]] =
  ## Collect join groups mentioning each table exactly once.

  for fld, val in obj[].fieldPairs:
    if val.model.isSome:
      let
        subMod = get val.model
        grp = (tbl: typeof(subMod).table, lFld: obj.fCol(fld), rFld: subMod.fCol("id"))

      if grp.tbl notin tbls:
        result.add grp
        tbls.add grp.tbl

      result.add subMod.joinGroups(tbls)

func joinGroups*[T: Model](obj: T): seq[tuple[tbl, lFld, rFld: string]] =
  ##[ For each `Model`_ field of `Model`_ instance, get:
  - table name for the field type
  - full column name for the field
  - full column name for ``id`` field of the field type

  Used to construct ``JOIN`` statements: ``JOIN {tbl} ON {lFld} = {rFld}``
  ]##

  var tbls: seq[string]
  obj.joinGroups(tbls)
