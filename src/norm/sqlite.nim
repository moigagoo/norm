import strutils
import options
import std/with
import macros

import ndb/sqlite
export sqlite

import norm/private/dot
import norm/private/sqlite/[dbtypes, rowutils]
import norm/model
import norm/pragmas


using dbConn: DbConn

proc dropTable*[T: Model](dbConn; obj: T) =
  ## Drop table for ``norm.Model``.

  let qry = sql("DROP TABLE IF EXISTS $#" % T.table)

  dbConn.exec qry

proc dropTables*[T: Model](dbConn; obj: T) =
  ## Drop tables for ``norm.Model`` and its ``norm.Model`` fields.

  for fld, val in obj.fieldPairs:
    when val is Model:
      with dbConn:
        dropTables(val)

  with dbConn:
    dropTable(obj)

proc createTable*[T: Model](dbConn; obj: T, force = false) =
  ##[ Create table for ``norm.Model``. Tables for ``norm.Model`` fields must exist beforehand.

  If ``force`` is ``true``, drop the table before creation.
  ]##

  if force:
    with dbConn:
      dropTable(obj)

  var colGroups, fkGroups: seq[string]

  for fld, val in obj.fieldPairs:
    var colShmParts: seq[string]

    colShmParts.add obj.col(fld)

    colShmParts.add typeof(val).dbType

    when val isnot Option:
      colShmParts.add "NOT NULL"

    when obj.dot(fld).hasCustomPragma(pk):
      colShmParts.add "PRIMARY KEY"

    when val is Model:
      fkGroups.add "FOREIGN KEY($#) REFERENCES $#($#)" % [obj.col(fld), val.table, val.col("id")]

    colGroups.add colShmParts.join(" ")

  let qry = sql("CREATE TABLE $#($#)" % [T.table, (colGroups & fkGroups).join(", ")])

  dbConn.exec qry

proc createTables*[T: Model](dbConn; obj: T, force = false) =
  ##[ Create tables for ``norm.Model`` and its ``norm.Model`` fields.

  If ``force`` is ``true``, drop the tables before creation.
  ]##

  for fld, val in obj.fieldPairs:
    when val is Model:
      with dbConn:
        createTables(val, force = force)

  with dbConn:
    createTable(obj, force = force)

proc insert*[T: Model](dbConn; obj: var T) =
  ## Insert rows for ``norm.Model`` instance and its ``norm.Model`` fields, updating their ``id``s.

  for fld, val in obj.fieldPairs:
    when val is Model:
      with dbConn:
        insert val

  let
    row = obj.toRow()
    phds = "?".repeat(row.len)
    qry = sql("INSERT INTO $# ($#) VALUES($#)" % [T.table, obj.cols.join(", "), phds.join(", ")])

  obj.id = dbConn.insertID(qry, row).int

# proc getOne*[T: Model](dbConn; obj: var T, cond: string, params: varargs[DbValue, dbValue]) =
#   let
#     joinStmts = collect(newSeq):
#       for grp in obj.joinGroups:
#         "JOIN $# ON $# = $#" % [grp.tbl, grp.lftFld, grp.rgtFld]
#     query = "SELECT $# FROM $# $# WHERE $#" % [obj.fullColNames.join(", "), T.tableName, joinStmts.join(" "), cond]
#     row = dbConn.getRow(sql query, params)

#   if row.isNone:
#     raise newException(KeyError, "No record found")

#   obj.fromRow(get row)
