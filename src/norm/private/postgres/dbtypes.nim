##[ Procs to convert between Nim types and SQLite types and between Nim values and ``ndb.postgres.DbValue``.

To add support for ``YourType``, define three procs:
- ``dbType(T: typedesc[YourType]) -> string`` that returns SQL type for given ``YourType``
- ``dbValue(YourType) -> DbValue`` that converts instances of ``YourType`` to ``ndb.sqlite.DbValue``
- ``to(DbValue, T: typedesc[YourType]) -> T`` that converts ``ndb.sqlite.DbValue`` instances to ``YourType``.
]##


import options
import times

import ndb/postgres

import ../../model


# Procs that return an SQLite type for a given Nim type:

proc dbType*(T: typedesc[SomeInteger]): string = "INTEGER"

proc dbType*(T: typedesc[SomeFloat]): string = "REAL"

proc dbType*(T: typedesc[string]): string = "TEXT"

proc dbType*(T: typedesc[bool]): string = "BOOLEAN"

proc dbType*(T: typedesc[DateTime]): string = "TIMESTAMP WITH TIME ZONE"

proc dbType*(T: typedesc[Model]): string = "INTEGER"

proc dbType*[T](_: typedesc[Option[T]]): string = dbType T


# Converter procs from Nim values to ``DbValue``:

proc dbValue*[T: Model](val: T): DbValue = dbValue(val.id)


# Converter procs from ``DbValue`` instances to Nim types:

using dbVal: DbValue

proc to*(dbVal; T: typedesc[SomeInteger]): T = dbVal.i.T

proc to*(dbVal; T: typedesc[SomeFloat]): T = dbVal.f.T

proc to*(dbVal; T: typedesc[string]): T = dbVal.s

proc to*(dbVal; T: typedesc[bool]): T = dbVal.b

proc to*(dbVal; T: typedesc[DateTime]): T = dbVal.t

proc to*[T](dbVal; O: typedesc[Option[T]]): O =
  case dbVal.kind
  of dvkNull:
    none T
  else:
    some dbVal.to(T)
