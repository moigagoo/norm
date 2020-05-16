import options
import strutils
import sugar

import ndb/sqlite
export sqlite

import pragmas
import model
import sqlite/[dbtypes, rowutils]

export rowutils


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
