import options
import times

import ndb/sqlite

import ../model


proc dbType*(T: typedesc[SomeInteger]): string = "INTEGER"

proc dbType*(T: typedesc[SomeFloat]): string = "FLOAT"

proc dbType*(T: typedesc[string]): string = "TEXT"

proc dbType*(T: typedesc[DbBlob]): string = "BLOB"

proc dbType*(T: typedesc[DateTime]): string = "INTEGER"

proc dbType*(T: typedesc[Model]): string = "INTEGER"

proc dbType*[T](_: typedesc[Option[T]]): string = dbType T
