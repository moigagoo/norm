const
  dbBackend* {.strdefine.}: string = "sqlite"
  dbConnection* {.strdefine.}: string = ""
  dbUser* {.strdefine.}: string = ""
  dbPassword* {.strdefine.}: string = ""
  dbDatabase* {.strdefine.}: string = ""

when dbBackend == "sqlite":
  import ndb/sqlite
elif dbBackend == "postgres":
  import ndb/postrges
else:
  raise newException LibraryError("No such backend: " & dbBackend)

import macros
import options
import times
import strutils
import strformat
import sequtils
import sugar
import std/with

from norm/objutils import dot

template pk* {.pragma.}

template ro* {.pragma.}

type
  Model* = object of RootObj
    id* {.pk, ro.}: int


template dbTable(val: string) {.pragma.}

template dbCol(val: string) {.pragma.}


type
  Bar* = object of Model
    bar*: int

  Foo* {.dbTable: "tratata".} = object of Model
    foo*: int
    b: Bar

  MyObj {.dbTable: "myObj".} = object of Model
    myField: int
    b: string
    c: Option[int]
    d: DateTime
    e: Option[DateTime]
    f: Foo
    g {.dbCol: "blobby".}: DbBlob

proc tableName(T: typedesc): string =
  when T.hasCustomPragma(dbTable):
    T.getCustomPragmaVal(dbTable)
  else:
    ($T).toLower()

proc initMyObj(): MyObj = MyObj(d: now(), e: some now())

proc dbType(T: typedesc[SomeInteger]): string = "INTEGER"
proc dbType(T: typedesc[SomeFloat]): string = "FLOAT"
proc dbType(T: typedesc[string]): string = "TEXT"
proc dbType(T: typedesc[DbBlob]): string = "BLOB"

proc dbType(T: typedesc[DateTime]): string = "INTEGER"
proc dbType(T: typedesc[Model]): string = "INTEGER"

proc dbType[T](_: typedesc[Option[T]]): string = dbType T

proc dbValue(v: DateTime): DbValue = ?v.toTime().toUnix()
proc dbValue[T: Model](v: T): DbValue = ?v.id

using
  dbVal: DbValue

proc to(dbVal; T: typedesc[SomeInteger]): T = dbVal.i.T
proc to(dbVal; T: typedesc[SomeFloat]): T = dbVal.f.T
proc to(dbVal; T: typedesc[string]): T = dbVal.s
proc to(dbVal; T: typedesc[DbBlob]): T = dbVal.b

proc to(dbVal; T: typedesc[DateTime]): T = dbVal.i.fromUnix().utc

proc to[T](dbVal; O: typedesc[Option[T]]): O =
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

proc fromRow[T: Model](obj: var T, row: Row) =
  var pos: Natural = 0
  obj.fromRowPos(row, pos)

proc toRow[T: Model](obj: T): Row =
  for fld, val in obj.fieldPairs:
    if not obj.dot(fld).hasCustomPragma(ro):
      result.add ?val

template colName[T: Model](obj: T, fld: string): string =
  when obj.dot(fld).hasCustomPragma(dbCol):
    obj.dot(fld).getCustomPragmaVal(dbCol)
  else:
    fld.toLower()

template fullColName[T: Model](obj: T, fld: string): string =
  "$#.$#" % [T.tableName, obj.colName(fld)]

proc colNames[T: Model](obj: T): seq[string] =
  for fld, val in obj.fieldPairs:
    when val is Model:
      result.add val.colNames
    else:
      result.add obj.colName(fld)

proc nroColNames[T: Model](obj: T): seq[string] =
  for fld, val in obj.fieldPairs:
    when not obj.dot(fld).hasCustomPragma(ro):
      result.add obj.colName(fld)

proc fullColNames[T: Model](obj: T): seq[string] =
  for fld, val in obj.fieldPairs:
    when val is Model:
      result.add val.fullColNames
    else:
      result.add obj.fullColName(fld)

proc joinGroups[T: Model](obj: T): seq[tuple[tbl, lftFld, rgtFld: string]] =
  for fld, val in obj.fieldPairs:
    when val is Model:
      result.add (tbl: typeof(val).tableName, lftFld: obj.fullColName(fld), rgtFld: val.fullColName("id"))
      result.add val.joinGroups

using dbConn: DbConn

proc dropTable*[T: Model](dbConn; obj: T) =
  let query = sql "DROP TABLE $#" % T.tableName

  dbConn.exec query

proc createTable*[T: Model](dbConn; obj: T, force = false) =
  if force:
    dbConn.dropTable(obj)

  var colGroups, fkGroups: seq[string]

  for fld, val in obj.fieldPairs:
    var colShmParts: seq[string]

    colShmParts.add obj.colName(fld)

    colShmParts.add typeof(val).dbType

    when val isnot Option:
      colShmParts.add "NOT NULL"

    when obj.dot(fld).hasCustomPragma(pk):
      colShmParts.add "PRIMARY KEY"

    when val is Model:
      fkGroups.add "FOREIGN KEY($#) REFERENCES $#($#)" % [obj.colName(fld), typeof(val).tableName, val.colName("id")]

    colGroups.add colShmParts.join(" ")

  let query = sql "CREATE TABLE $#($#)" % [T.tableName, (colGroups & fkGroups).join(", ")]

  dbConn.exec query

proc insertId*[T: Model](dbConn; obj: T): int =
  let
    row = obj.toRow()
    plcs = "?".repeat(row.len)
    query = sql "INSERT INTO $# ($#) VALUES($#)" % [T.tableName, obj.nroColNames.join(", "), plcs.join(", ")]

  dbConn.insertID(query, row).int

proc insert*[T: Model](dbConn; obj: var T) =
  obj.id = dbConn.insertId(obj)

proc getOne*[T: Model](dbConn; obj: var T, cond: string, params: varargs[DbValue, dbValue]) =
  let
    joinStmts = collect(newSeq):
      for grp in obj.joinGroups:
        "JOIN $# ON $# = $#" % [grp.tbl, grp.lftFld, grp.rgtFld]
    query = "SELECT $# FROM $# $# WHERE $#" % [obj.fullColNames.join(", "), T.tableName, joinStmts.join(" "), cond]
    row = dbConn.getRow(sql query, params)

  if row.isNone:
    raise newException(KeyError, "No record found")

  obj.fromRow(get row)

var o = initMyObj()

let db = open(dbConnection, dbUser, dbPassword, dbDatabase)

var f = Foo()

var b = Bar()

b.bar = 333
with db:
  insert(b)

f.b = b
with db:
  insert(f)

o.f = f
with db:
  insert(o)

var oo = initMyObj()

# let cond = &"""{oo.id} = ?"""
let cond = &"""{oo.fullColName("id")} = ?"""
echo cond

db.getOne(oo, cond, 19)
echo oo
echo oo.f
echo oo.f.b

db.close()
