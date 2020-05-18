##[ Procs to convert between Nim types and SQLite types and between Nim values and ``DbValue``.

To add support for ``YourType``, define:
- ``dbType(T: typedesc[YourType]) -> string``
- ``dbValue(YourType) -> DbValue``
- ``to(DbValue, T: typedesc[YourType]) -> T
]##


import options
import times

import ndb/sqlite

import norm/model


## Procs that return an SQLite type for a given Nim type:

proc dbType*(T: typedesc[SomeInteger]): string = "INTEGER"

proc dbType*(T: typedesc[SomeFloat]): string = "FLOAT"

proc dbType*(T: typedesc[string]): string = "TEXT"

proc dbType*(T: typedesc[bool]): string = "INTEGER"

proc dbType*(T: typedesc[DbBlob]): string = "BLOB"

proc dbType*(T: typedesc[DateTime]): string = "FLOAT"

proc dbType*(T: typedesc[Model]): string = "INTEGER"

proc dbType*[T](_: typedesc[Option[T]]): string = dbType T


## Converter procs from Nim values to ``DbValue``:

proc dbValue*(val: bool): DbValue = dbValue(if val: 1 else: 0)

proc dbValue*(val: Option[bool]): DbValue =
  if val.isSome:
    dbValue(get(val))
  else:
    dbValue(nil)

proc dbValue*(val: DateTime): DbValue = dbValue(val.toTime().toUnixFloat())

proc dbValue*[T: Model](val: T): DbValue = dbValue(val.id)


## Converter procs from ``DbValue`` instances to Nim types:

using dbVal: DbValue

proc to*(dbVal; T: typedesc[SomeInteger]): T = dbVal.i.T

proc to*(dbVal; T: typedesc[SomeFloat]): T = dbVal.f.T

proc to*(dbVal; T: typedesc[string]): T = dbVal.s

proc to*(dbVal; T: typedesc[bool]): T =
  case dbVal.i
  of 0:
    false
  else:
    true

proc to*(dbVal; T: typedesc[DbBlob]): T = dbVal.b

proc to*(dbVal; T: typedesc[DateTime]): T = utc dbVal.f.fromUnixFloat()

proc to*[T](dbVal; O: typedesc[Option[T]]): O =
  case dbVal.kind
  of dvkNull:
    none T
  else:
    some dbVal.to(T)
