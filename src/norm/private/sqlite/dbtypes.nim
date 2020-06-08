##[ Funcs to convert between Nim types and SQLite types and between Nim values and ``ndb.sqlite.DbValue``.

To add support for ``YourType``, define three funcs:
- ``dbType(T: typedesc[YourType]) -> string`` that returns SQL type for given ``YourType``
- ``dbValue(YourType) -> DbValue`` that converts instances of ``YourType`` to ``ndb.sqlite.DbValue``
- ``to(DbValue, T: typedesc[YourType]) -> T`` that converts ``ndb.sqlite.DbValue`` instances to ``YourType``.
]##


import options
import times

import ndb/sqlite

import ../../model


# Funcs that return an SQLite type for a given Nim type:

func dbType*(T: typedesc[SomeInteger]): string = "INTEGER"

func dbType*(T: typedesc[SomeFloat]): string = "FLOAT"

func dbType*(T: typedesc[string]): string = "TEXT"

func dbType*(T: typedesc[bool]): string = "INTEGER"

func dbType*(T: typedesc[DbBlob]): string = "BLOB"

func dbType*(T: typedesc[DateTime]): string = "FLOAT"

func dbType*(T: typedesc[Model]): string = "INTEGER"

func dbType*[T](_: typedesc[Option[T]]): string = dbType T


# Converter funcs from Nim values to ``DbValue``:

func dbValue*(val: bool): DbValue = dbValue(if val: 1 else: 0)

func dbValue*(val: DateTime): DbValue = dbValue(val.toTime().toUnixFloat())

func dbValue*[T: Model](val: T): DbValue = dbValue(val.id)

func dbValue*(val: Option[bool]): DbValue =
  if val.isSome:
    dbValue(get(val))
  else:
    dbValue(nil)

func dbValue*(val: Option[DateTime]): DbValue =
  if val.isSome:
    dbValue(get(val))
  else:
    dbValue(nil)

func dbValue*[T: Model](val: Option[T]): DbValue =
  if val.isSome:
    dbValue(get(val))
  else:
    dbValue(nil)


# Converter funcs from ``DbValue`` instances to Nim types:

using dbVal: DbValue

func to*(dbVal; T: typedesc[SomeInteger]): T = dbVal.i.T

func to*(dbVal; T: typedesc[SomeFloat]): T = dbVal.f.T

func to*(dbVal; T: typedesc[string]): T = dbVal.s

func to*(dbVal; T: typedesc[bool]): T =
  case dbVal.i
  of 0:
    false
  else:
    true

func to*(dbVal; T: typedesc[DbBlob]): T = dbVal.b

proc to*(dbVal; T: typedesc[DateTime]): T = utc dbVal.f.fromUnixFloat()

func to*(dbVal; T: typedesc[Model]): T =
  ## This is never called and exists only to please the compiler.

  discard

func to*[T](dbVal; O: typedesc[Option[T]]): O =
  case dbVal.kind
  of dvkNull:
    none T
  else:
    some dbVal.to(T)
