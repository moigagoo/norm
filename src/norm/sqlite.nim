import std/[os, logging, strutils, sequtils, options, sugar]

when (NimMajor, NimMinor) <= (1, 6):
  import pragmasutils
  from std/macros import newCall, bindSym, nnkDotExpr, newTree, ident
  export pragmasutils
else:
  import std/macros
  export macros

import ndb/sqlite
export sqlite

import private/sqlite/[dbtypes, rowutils]
import private/[dot, log]
import model
import pragmas

export dbtypes


type
  RollbackError* = object of CatchableError
    ##[ Raised when transaction is manually rollbacked.

    Do not raise manually, use `rollback <#rollback>`_ proc.
    ]##
  NotFoundError* = object of KeyError
  ConflictPolicy* = enum
    cpRaise
    cpIgnore
    cpReplace


const dbHostEnv* = "DB_HOST"


# Sugar to get DB config from environment variables

proc getDb*(): DbConn =
  ## Create a ``DbConn`` from ``DB_HOST`` environment variable.

  open(getEnv(dbHostEnv), "", "", "")

template withDb*(body: untyped): untyped =
  ##[ Wrapper for DB operations.

  Creates a ``DbConn`` with `getDb <#getDb>`_ as ``db`` variable,
  runs your code in a ``try`` block, and closes ``db`` afterward.
  ]##

  block:
    let db {.inject.} = getDb()

    try:
      body

    finally:
      close db


using dbConn: DbConn


# DB manipulation

proc dropDb* =
  ## Remove the DB file defined in environment variable.

  removeFile(getEnv(dbHostEnv))


# Table manipulation

proc createTables*[T: Model](dbConn; obj: T) =
  ## Create tables for `Model`_ and its `Model`_ fields.

  for fld, val in obj[].fieldPairs:
    if val.model.isSome:
      dbConn.createTables(get val.model)

  var colGroups, fkGroups: seq[string]

  for fld, val in obj[].fieldPairs:
    var colShmParts: seq[string]

    colShmParts.add obj.col(fld)

    colShmParts.add typeof(val).dbType

    when val isnot Option:
      colShmParts.add "NOT NULL"

    when obj.dot(fld).hasCustomPragma(pk):
      colShmParts.add "PRIMARY KEY"

    when obj.dot(fld).hasCustomPragma(unique):
      colShmParts.add "UNIQUE"

    if val.isModel:
      var fkGroup = "FOREIGN KEY($#) REFERENCES $#($#)" %
        [obj.col(fld), typeof(get val.model).table, typeof(get val.model).col("id")]

      when obj.dot(fld).hasCustomPragma(onDelete):
        fkGroup &= " ON DELETE " & obj.dot(fld).getCustomPragmaVal(onDelete)

      fkGroups.add fkGroup

    when obj.dot(fld).hasCustomPragma(fk):
      when val isnot SomeInteger and val isnot Option[SomeInteger]:
        {.fatal: "Pragma fk: field must be SomeInteger. " & fld & " is not SomeInteger.".}
      elif obj.dot(fld).getCustomPragmaVal(fk) isnot Model and obj isnot obj.dot(fld).getCustomPragmaVal(fk):
        const pragmaValTypeName = $(obj.dot(fld).getCustomPragmaVal(fk))
        {.fatal: "Pragma fk: value must be a Model. " & pragmaValTypeName & " is not a Model.".}
      elif obj is obj.dot(fld).getCustomPragmaVal(fk):
        when T.hasCustomPragma(tableName):
          const selfTableName = '"' & T.getCustomPragmaVal(tableName) & '"'
        else:
          const selfTableName = '"' & $T & '"'
        fkGroups.add "FOREIGN KEY ($#) REFERENCES $#(id)" % [fld, selfTableName]
      else:
        fkGroups.add "FOREIGN KEY ($#) REFERENCES $#(id)" % [fld, (obj.dot(fld).getCustomPragmaVal(fk)).table]

    colGroups.add colShmParts.join(" ")

  let qry = "CREATE TABLE IF NOT EXISTS $#($#)" % [T.table, (colGroups & fkGroups).join(", ")]

  log(qry)

  dbConn.exec(sql qry)

# Row manipulation

proc insert*[T: Model](dbConn; obj: var T, force = false, conflictPolicy = cpRaise) =
  ##[ Insert rows for `Model`_ instance and its `Model`_ fields, updating their ``id`` fields.

  By default, if the inserted object's ``id`` is not 0, the object is considered already inserted and is not inserted again. You can force new insertion with ``force = true``.

  ``conflictPolicy`` determines how the proc reacts to insertion conflicts. ``cpRaise`` means raise a ``DbError``, ``cpIgnore`` means ignore the conflict and do not insert the conflicting row, ``cpReplace`` means overwrite the older row with the newer one.
  ]##

  checkRo(T)

  if obj.id != 0 and not force:
    log("Object ID is not 0, skipping insertion. Type: $#, ID: $#" % [$T, $obj.id])

    return

  for fld, val in obj[].fieldPairs:
    if val.model.isSome:
      var subMod = get val.model
      dbConn.insert(subMod)

  let
    row = obj.toRow()
    phds = "?".repeat(row.len)
    action = case conflictPolicy
      of cpRaise: "INSERT"
      of cpIgnore: "INSERT OR IGNORE"
      of cpReplace: "INSERT OR REPLACE"
    qry = "$# INTO $# ($#) VALUES($#)" % [action, T.table, obj.cols.join(", "), phds.join(", ")]

  log(qry, $row)

  obj.id = dbConn.insertID(sql qry, row)

proc insert*[T: Model](dbConn; objs: var openArray[T], force = false, conflictPolicy = cpRaise) =
  ## Insert rows for each `Model`_ instance in open array.

  for obj in objs.mitems:
    dbConn.insert(obj, force, conflictPolicy)

proc select*[T: Model](dbConn; obj: var T, cond: string, params: varargs[DbValue, dbValue]) {.raises: {NotFoundError, ValueError, DbError, LoggingError}.} =
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
        "LEFT JOIN $# AS $# ON $# = $#" % [grp.tbl, grp.tAls, grp.lFld, grp.rFld]
    qry = "SELECT $# FROM $# $# WHERE $#" % [obj.rfCols.join(", "), T.table, joinStmts.join(" "), cond]

  log(qry, $params)

  let row = dbConn.getRow(sql qry, params)

  if row.isNone:
    raise newException(NotFoundError, "Record not found")

  obj.fromRow(get row)

proc select*[T: Model](dbConn; objs: var seq[T], cond: string, params: varargs[DbValue, dbValue]) {.raises: {ValueError, DbError, LoggingError}.} =
  ##[ Populate a sequence of `Model`_ instances from DB.

  ``objs`` must have at least one item.
  ]##

  if objs.len < 1:
    raise newException(ValueError, "``objs`` must have at least one item.")

  let
    joinStmts = collect(newSeq):
      for grp in objs[0].joinGroups:
        "LEFT JOIN $# AS $# ON $# = $#" % [grp.tbl, grp.tAls, grp.lFld, grp.rFld]
    qry = "SELECT $# FROM $# $# WHERE $#" % [objs[0].rfCols.join(", "), T.table, joinStmts.join(" "), cond]

  log(qry, $params)

  let rows = dbConn.getAllRows(sql qry, params)

  if objs.len > rows.len:
    objs.setLen(rows.len)

  for _ in 1..(rows.len - objs.len):
    objs.add deepCopy(objs[0])

  for i, row in rows:
    objs[i].fromRow(row)

proc selectAll*[T: Model](dbConn; objs: var seq[T]) =
  ##[ Populate a sequence of `Model`_ instances from DB, fetching all rows in the matching table.

  ``objs`` must have at least one item.

  **Warning:** this is a dangerous operation because you don't control how many rows will be fetched.
  ]##

  dbConn.select(objs, "1")

proc count*(dbConn; T: typedesc[Model], col = "*", dist = false, cond = "1", params: varargs[DbValue, dbValue]): int64 =
  ##[ Count rows matching condition without fetching them.

  To count rows with non-NULL values in a particular column, pass the column name in ``col`` param.

  To count only unique column values, use ``dist = true`` (stands for “distinct.”)
  ]##

  let qry = "SELECT COUNT($# $#) FROM $# WHERE $#" % [if dist: "DISTINCT" else: "", col, T.table, cond]

  log(qry, $params)

  get dbConn.getValue(int64, sql qry, params)

proc sum*(dbConn; T: typedesc[Model], col: string, dist = false, cond = "1", params: varargs[DbValue, dbValue]): float =
  ##[ Sum column values matching condition without fetching them.

  To sum only unique column values, use ``dist = true`` (stands for “distinct.”)
  ]##

  let qry = "SELECT SUM($# $#) FROM $# WHERE $#" % [if dist: "DISTINCT" else: "", col, T.table, cond]

  log(qry, $params)

  get dbConn.getValue(float, sql qry, params)

proc exists*(dbConn; T: typedesc[Model], cond = "1", params: varargs[DbValue, dbValue]): bool =
  ## Check if a row exists in the table.

  let qry = "SELECT EXISTS(SELECT NULL FROM $# WHERE $#)" % [T.table, cond]

  log(qry, $params)

  bool(get dbConn.getValue(int64, sql qry, params))

proc update*[T: Model](dbConn; obj: var T) =
  ## Update rows for `Model`_ instance and its `Model`_ fields.

  checkRo(T)

  for fld, val in obj[].fieldPairs:
    if val.model.isSome:
      var subMod = get val.model
      dbConn.update(subMod)

  let
    row = obj.toRow()
    phds = collect(newSeq):
      for col in obj.cols:
        "$# = ?" % col
    qry = "UPDATE $# SET $# WHERE id = $#" % [T.table, phds.join(", "), $obj.id]

  log(qry, $row)

  dbConn.exec(sql qry, row)

proc update*[T: Model](dbConn; objs: var openArray[T]) =
  ## Update rows for each `Model`_ instance in open array.

  for obj in objs.mitems:
    dbConn.update(obj)

proc delete*[T: Model](dbConn; obj: var T) =
  ## Delete rows for `Model`_ instance and its `Model`_ fields.

  checkRo(T)

  let qry = "DELETE FROM $# WHERE id = $#" % [T.table, $obj.id]

  log(qry)

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
    log(beginQry)
    dbConn.exec(sql beginQry)

    body

    log(commitQry)
    dbConn.exec(sql commitQry)

  except:
    log(rollbackQry)
    dbConn.exec(sql rollbackQry)

    raise

proc selectOneToMany*[O: Model, M: Model](dbConn; oneEntry: O, relatedEntries: var seq[M], foreignKeyFieldName: static string) =
  ## Fetches all entries of a "many" side from a one-to-many relationship 
  ## between the model of `oneEntry` and the model of `relatedEntries`. It is
  ## ensured at compile time that the field specified here is a valid foreign key
  ## field on oneEntry pointing to the table of the `relatedEntries`-model.
  const _ = validateFkField(foreignKeyFieldName, M, O) # '_' is irrelevant, but the assignment is required for 'validateFkField' to run properly

  const manyTableName = M.table()
  const sqlCondition = "$#.$# = ?" % [manyTableName, foreignKeyFieldName]

  dbConn.select(relatedEntries, sqlCondition, oneEntry.id)

proc selectOneToMany*[O: Model, M: Model](dbConn; oneEntry: O, relatedEntries: var seq[M]) =
  ## A convenience proc. Fetches all entries of a "many" side from a one-to-many 
  ## relationship between the model of `oneEntry` and the model of `relatedEntries`.
  ## The field used to fetch the `relatedEntries` is automatically inferred as long
  ## as the `relatedEntries` model has only one field pointing to the model of 
  ## `oneEntry`. Will not compile if `relatedEntries` has multiple fields that 
  ## point to the model of `oneEntry`. Specify the `foreignKeyFieldName` parameter 
  ## in such a case.
  const foreignKeyFieldName: string = M.getRelatedFieldNameTo(O)
  selectOneToMany(dbConn, oneEntry, relatedEntries, foreignKeyFieldName)

macro unpackFromJoinModel[T: Model](mySeq: seq[T], field: static string): untyped =
  ## A macro to "extract" a field of name `field` out of the model in `mySeq`, 
  ## creating a new seq of whatever type the field called `field` has.
  newCall(bindSym"mapIt", mySeq, nnkDotExpr.newTree(ident"it", ident field))

proc selectManyToMany*[M1: Model, J: Model, M2: Model](dbConn; queryStartEntry: M1, joinModelEntries: var seq[J], queryEndEntries: var seq[M2], fkColumnFromJoinToManyStart: static string, fkColumnFromJoinToManyEnd: static string) =    
  ## Fetches the many-to-many relationship for the entry `queryStartEntry` and
  ## returns a seq of all entries connected to `queryStartEntry` in `queryEndEntries`. 
  ## Requires to also be passed the model connecting the many-to-many relationship
  ## via `joinModelEntries`in order to fetch the relationship. Also requires the
  ## field on the joinModel that points to the table of `queryStartEntry`
  ## via the parameter `fkColumnFromJoinToManyStart`. Also requires the field field on
  ## the joinModel that points to the table of `queryEndEntries` via the parameter
  ## `fkColumnFromJoinToManyEnd`.
  ## Will not compile if the specified fields on the joinModel do not properly point
  ## to the tables of `queryStartEntry` and `queryEndEntries`.
  static: discard validateFkField(fkColumnFromJoinToManyStart, J, M1) # 'tmp1' is irrelevant, but the assignment is required for 'validateFkField' to run properly
  static: discard validateFkField(fkColumnFromJoinToManyEnd, J, M2) # 'tmp2' is irrelevant, but the assignment is required for 'validateFkField' to run properly 
  
  const joinTableName = J.table()
  const sqlCondition: string = "$#.$# = ?" % [joinTableName, fkColumnFromJoinToManyStart]
  dbConn.select(joinModelEntries, sqlCondition, queryStartEntry.id)

  let unpackedEntries: seq[M2] = unpackFromJoinModel(joinModelEntries, fkColumnFromJoinToManyEnd)

  queryEndEntries = unpackedEntries

proc selectManyToMany*[M1: Model, J: Model, M2: Model](dbConn; queryStartEntry: M1, joinModelEntries: var seq[J], queryEndEntries: var seq[M2]) =    
  ## A convenience proc. Fetches the many-to-many relationship for the entry 
  ## `queryStartEntry` and returns a seq of all entries connected to `queryStartEntry` 
  ## in `queryEndEntries`. Requires to also be passed the model connecting the 
  ## many-to-many relationship via `joinModelEntries`in order to fetch the relationship.
  ## The fields on `joinModelEntries` to use for these queries are inferred. 
  ## Will only compile if the joinModel has exactly one field pointing to 
  ## the table of `queryStartEntry` as well as exactly one field pointing to 
  ## the table of `queryEndEntries`. Specify the parameters `fkColumnFromJoinToManyStart`
  ## and `fkColumnFromJoinToManyEnd` if that is not the case.
  const fkColumnFromJoinToManyStart: string = J.getRelatedFieldNameTo(M1)
  const fkColumnFromJoinToManyEnd: string = J.getRelatedFieldNameTo(M2)
  selectManyToMany(dbConn, queryStartEntry, joinModelEntries, queryEndEntries, fkColumnFromJoinToManyStart, fkColumnFromJoinToManyEnd)
