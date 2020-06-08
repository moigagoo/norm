##[ Funcs to convert between Nim types and SQLite types and between Nim values and ``ndb.postgres.DbValue``.

To add support for ``YourType``, define three funcs:
- ``dbType(T: typedesc[YourType]) -> string`` that returns SQL type for given ``YourType``
- ``dbValue(YourType) -> DbValue`` that converts instances of ``YourType`` to ``ndb.sqlite.DbValue``
- ``to(DbValue, T: typedesc[YourType]) -> T`` that converts ``ndb.sqlite.DbValue`` instances to ``YourType``.
]##


import options
import times

import ndb/postgres

import ../../model


# Funcs that return an SQLite type for a given Nim type:

func dbType*(T: typedesc[SomeInteger]): string = "INTEGER"

func dbType*(T: typedesc[SomeFloat]): string = "REAL"

func dbType*(T: typedesc[string]): string = "TEXT"

func dbType*(T: typedesc[bool]): string = "BOOLEAN"

func dbType*(T: typedesc[DateTime]): string = "TIMESTAMP WITH TIME ZONE"

func dbType*(T: typedesc[Model]): string = "INTEGER"

func dbType*[T](_: typedesc[Option[T]]): string = dbType T


# Converter funcs from Nim values to ``DbValue``:

func dbValue*[T: Model](val: T): DbValue = dbValue(val.id)

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

func to*(dbVal; T: typedesc[bool]): T = dbVal.b

func to*(dbVal; T: typedesc[DateTime]): T = dbVal.t

func to*(dbVal; T: typedesc[Model]): T =
  ## This is never called and exists only to please the compiler.

  discard

func to*[T](dbVal; O: typedesc[Option[T]]): O =
  case dbVal.kind
  of dvkNull:
    none T
  else:
    some dbVal.to(T)
