import options
import times
import macros

import ndb/sqlite

import ../model


proc dbValue*(val: DateTime): DbValue = dbValue(val.toTime().toUnix())

proc dbValue*[T: Model](val: T): DbValue = dbValue(val.id)

using
  dbVal: DbValue

proc to*(dbVal; T: typedesc[SomeInteger]): T = dbVal.i.T

proc to*(dbVal; T: typedesc[SomeFloat]): T = dbVal.f.T

proc to*(dbVal; T: typedesc[string]): T = dbVal.s

proc to*(dbVal; T: typedesc[DbBlob]): T = dbVal.b

proc to*(dbVal; T: typedesc[DateTime]): T = dbVal.i.fromUnix().utc

proc to*[T](dbVal; O: typedesc[Option[T]]): O =
  case dbVal.kind
  of dvkNull:
    none T
  else:
    some dbVal.to(T)

proc fromRowPos[T: Model](obj: var T, row: Row, pos: var Natural) =
  for fld, val in obj.fieldPairs:
    when val is Model:
      val.fromRowPos(row, pos)

    else:
      val = row[pos].to(typeof(val))
      inc pos

proc fromRow*[T: Model](obj: var T, row: Row) =
  var pos: Natural = 0
  obj.fromRowPos(row, pos)

proc toRow*[T: Model](obj: T): Row =
  for fld, val in obj.fieldPairs:
    if not obj.dot(fld).hasCustomPragma(ro):
      result.add dbValue(val)
