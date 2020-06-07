import logging
import strutils
import sequtils
import options
import macros
import sugar

import ndb/postgres
export postgres

import private/postgres/[dbtypes, rowutils]
import private/dot
import model
import pragmas


type
  RollbackError* = object of CatchableError
    ##[ Raised when transaction is manually rollbacked.

    Do not raise manually, use `rollback <#rollback>`_ proc.
    ]##


using dbConn: DbConn


# Table manupulation

proc createTables*[T: Model](dbConn; obj: T) =
  ## Create tables for `Model`_ and its `Model`_ fields.

  for fld, val in obj[].fieldPairs:
    if val.model.isSome:
      dbConn.createTables(get val.model)

  var colGroups, fkGroups: seq[string]

  for fld, val in obj[].fieldPairs:
    var colShmParts: seq[string]

    colShmParts.add obj.col(fld)

    when obj.dot(fld).hasCustomPragma(pk):
      colShmParts.add "SERIAL PRIMARY KEY"

    else:
      colShmParts.add typeof(val).dbType

      when val isnot Option:
        colShmParts.add "NOT NULL"

    if val.model.isSome:
      let subMod = get val.model
      fkGroups.add "FOREIGN KEY($#) REFERENCES $#($#)" % [obj.col(fld), typeof(subMod).table, subMod.col("id")]

    colGroups.add colShmParts.join(" ")

  let qry = "CREATE TABLE $#($#)" % [T.table, (colGroups & fkGroups).join(", ")]

  debug qry
  dbConn.exec(sql qry)


# Row manupulation

proc insert*[T: Model](dbConn; obj: var T) =
  ## Insert rows for `Model`_ instance and its `Model`_ fields, updating their ``id`` fields.

  for fld, val in obj[].fieldPairs:
    if val.model.isSome:
      var subMod = get val.model
      dbConn.insert(subMod)

  let
    row = obj.toRow()
    phds = collect(newSeq, for i, _ in row: "$" & $(i + 1))
    qry = "INSERT INTO $# ($#) VALUES($#)" % [T.table, obj.cols.join(", "), phds.join(", ")]

  debug "$# <- $#" % [qry, $row]
  obj.id = dbConn.insertID(sql qry, row).int

proc select*[T: Model](dbConn; obj: var T, cond: string, params: varargs[DbValue, dbValue]) =
  ##[ Populate a `Model`_ instance and its `Model`_ fields from DB.

  ``cond`` is condition for ``WHERE`` clause but with extra features:

  - use ``?`` placeholders and put the actual values in ``params``
  - use `table <model.html#table,typedesc[Model]>`_, \
    `col <model.html#col,T,string>`_, and `fCol <model.html#fCol,T,string>`_ procs \
    instead of hardcoded table and column names
  ]##

  let
    joinStmts = collect(newSeq):
      for grp in obj.joinGroups:
        "JOIN $# ON $# = $#" % [grp.tbl, grp.lFld, grp.rFld]
    qry = "SELECT $# FROM $# $# WHERE $#" % [obj.rfCols.join(", "), T.table, joinStmts.join(" "), cond]

  debug "$# <- $#" % [qry, $params]
  let row = dbConn.getRow(sql qry, params)

  if row.isNone:
    raise newException(KeyError, "Record not found")

  obj.fromRow(get row)

proc select*[T: Model](dbConn; objs: var seq[T], cond: string, params: varargs[DbValue, dbValue]) =
  ##[ Populate a sequence of `Model`_ instances from DB.

  ``objs`` must have at least one item.
  ]##

  if objs.len < 1:
    raise newException(ValueError, "``objs`` must have at least one item.")

  let
    joinStmts = collect(newSeq):
      for grp in objs[0].joinGroups:
        "JOIN $# ON $# = $#" % [grp.tbl, grp.lFld, grp.rFld]
    qry = "SELECT $# FROM $# $# WHERE $#" % [objs[0].rfCols.join(", "), T.table, joinStmts.join(" "), cond]

  debug "$# <- $#" % [qry, $params]
  let rows = dbConn.getAllRows(sql qry, params)

  if objs.len > rows.len:
    objs.setLen(rows.len)

  for _ in 1..(rows.len - objs.len):
    var obj: T
    new obj
    obj.deepCopy(objs[0])
    objs.add obj

  for i, row in rows:
    objs[i].fromRow(row)

proc update*[T: Model](dbConn; obj: var T) =
  ## Update rows for `Model`_ instance and its `Model`_ fields.

  for fld, val in obj[].fieldPairs:
    if val.model.isSome:
      var subMod = get val.model
      dbConn.update(subMod)

  let
    row = obj.toRow()
    phds = collect(newSeq):
      for i, col in obj.cols:
        "$# = $$$#" %  [col, $(i + 1)]
    qry = "UPDATE $# SET $# WHERE id = $#" % [T.table, phds.join(", "), $obj.id]

  debug "$# <- $#" % [qry, $row]
  dbConn.exec(sql qry, row)

proc update*[T: Model](dbConn; objs: var openArray[T]) =
  ## Update rows for each `Model`_ instance in open array.

  for obj in objs.mitems:
    dbConn.update(obj)

proc delete*[T: Model](dbConn; obj: var T) =
  ## Delete rows for `Model`_ instance and its `Model`_ fields.

  let qry = "DELETE FROM $# WHERE id = $#" % [T.table, $obj.id]

  debug qry
  dbConn.exec(sql qry)

  obj = nil

proc delete*[T: Model](dbConn; objs: var openArray[T]) =
  ## Delete rows for each `Model`_ instance in open array.

  for obj in objs.mitems:
    dbConn.delete(obj)


# Transactions

proc rollback* {.raises: RollbackError.} =
  ## Rollback transaction by raising `RollbackError <#RollbackError>`_.

  raise newException(RollbackError, "Rollback transaction.")

template transaction*(dbConn; body: untyped): untyped =
  ##[ Wrap code in DB transaction.

  If an exception is raised, the transaction is rollbacked.

  To rollback manually, call `rollback`_.
  ]##

  let
    beginQry = "BEGIN"
    commitQry = "COMMIT"
    rollbackQry = "ROLLBACK"

  try:
    debug beginQry
    dbConn.exec(sql beginQry)

    body

    debug commitQry
    dbConn.exec(sql commitQry)

  except:
    debug rollbackQry
    dbConn.exec(sql rollbackQry)
    raise
