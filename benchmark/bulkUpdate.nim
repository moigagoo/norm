from std/os import removeFile

import pkg/benchy
# from pkg/lowdb/sqlite as lowdb import DbConn

import norm/[model, sqlite]

import ../tests/models

const dbFile = "test.db"

proc updateEach*[T: Model](dbConn: DbConn; objs: var openArray[T]) =
  # https://github.com/moigagoo/norm/blob/9fe0105ccb47e4fd72f2e5b546dbea72b58cedeb/src/norm/sqlite.nim#L357

  for obj in objs.mitems:
    dbConn.update(obj)

template updateTime(name, body: untyped): untyped =
  block:
    let dbConn {.inject.} = open(dbFile, "", "", "")

    dbConn.createTables(newToy())

    var toys {.inject.}: seq[Toy]
    for i in 1..1000:
      var toy = newToy(float i)
      dbConn.insert toy
      toy.price *= 2
      toys.add toy
      
    timeIt name, 1:
      body

    removeFile dbFile

updateTime "Bulk update":
  dbConn.update toys

updateTime "Update each row":
  dbConn.updateEach toys
