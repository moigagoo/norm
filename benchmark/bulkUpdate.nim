from std/os import removeFile, copyFile
from std/strformat import fmt

import pkg/benchy

import norm/[model, sqlite]

import ../tests/models

const
  baseDbFile = "cleanBulkUpdate.db"
  dbFile = "bulkUpdate.db"

proc setupDb(dbFile: string; rows: int) =
  stderr.write fmt"Generating '{dbFile}' with {rows} rows"

  let dbConn = open(dbFile, "", "", "")

  dbConn.createTables newToy()

  var toys: seq[Toy]
  for i in 1..rows:
    stderr.write "."
    var toy = newToy(float i)
    dbConn.insert toy
    toys.add toy
  echo " done!\l"

template updateTime(name, body: untyped): untyped =
  block:
    stderr.write name & "\r"

    baseDbFile.copyFile dbFile

    let dbConn {.inject.} = open(dbFile, "", "", "")

    var toys {.inject.} = @[newToy()]
    dbConn.selectAll toys

    for toy in toys.mitems:
      toy.price *= 2

    timeIt name, 1:
      body

    removeFile dbFile

baseDbFile.setupDb 1000

updateTime "Bulk update":
  dbConn.update toys

updateTime "Update each row":
  # https://github.com/moigagoo/norm/blob/9fe0105ccb47e4fd72f2e5b546dbea72b58cedeb/src/norm/sqlite.nim#L357
  for toy in toys.mitems:
    dbConn.update toy

removeFile baseDbFile
