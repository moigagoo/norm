import macros
import options
import times
import std/with
import strformat

import norm/model
import norm/pragmas
import norm/sqlite


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

proc initMyObj(): MyObj = MyObj(d: now(), e: some now())

var o = initMyObj()

let db = open("app.db", "", "", "")

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

# let cond = fmt"""{oo.id} = ?"""
let cond = fmt"""{oo.fullColName("id")} = ?"""
echo cond

db.getOne(oo, cond, 19)
echo oo
echo oo.f
echo oo.f.b

db.close()
