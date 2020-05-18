import strutils
import macros

import norm/private/dot
import norm/pragmas


type
  Model* = object of RootObj
    id* {.pk, ro.}: int


proc tableName*(T: typedesc[Model]): string =
  when T.hasCustomPragma(dbTable):
    T.getCustomPragmaVal(dbTable)
  else:
    $T

template colName*[T: Model](obj: T, fld: string): string =
  when obj.dot(fld).hasCustomPragma(dbCol):
    obj.dot(fld).getCustomPragmaVal(dbCol)
  else:
    fld

template fullColName*[T: Model](obj: T, fld: string): string =
  "$#.$#" % [T.tableName, obj.colName(fld)]

proc colNames*[T: Model](obj: T): seq[string] =
  for fld, val in obj.fieldPairs:
    when val is Model:
      result.add val.colNames
    else:
      result.add obj.colName(fld)

proc nroColNames*[T: Model](obj: T): seq[string] =
  for fld, val in obj.fieldPairs:
    when not obj.dot(fld).hasCustomPragma(ro):
      result.add obj.colName(fld)

proc fullColNames*[T: Model](obj: T): seq[string] =
  for fld, val in obj.fieldPairs:
    when val is Model:
      result.add val.fullColNames
    else:
      result.add obj.fullColName(fld)

proc joinGroups*[T: Model](obj: T): seq[tuple[tbl, lftFld, rgtFld: string]] =
  for fld, val in obj.fieldPairs:
    when val is Model:
      result.add (tbl: typeof(val).tableName, lftFld: obj.fullColName(fld), rgtFld: val.fullColName("id"))
      result.add val.joinGroups
