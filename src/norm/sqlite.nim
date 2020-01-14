##[

##############
SQLite Backend
##############

The following Nim types are converted automatically:

==================== ====================
Nim Type             SQLite Type
==================== ====================
``int``              ``INTEGER NOT NULL``
``string``           ``TEXT NOT NULL``
``float``            ``REAL NOT NULL``
``bool``             ``INTEGER NOT NULL``
``DateTime``         ``INTEGER NOT NULL``
``Option[int]``      ``INTEGER``
``Option[string]``   ``TEXT``
``Option[float]``    ``REAL``
``Option[bool]``     ``INTEGER``
``Option[DateTime]`` ``INTEGER``
==================== ====================

Nim ``true`` and ``false`` values are stored as ``1`` and ``0``.

Nim ``times.DateTime`` values are stored as ``INTEGER`` Unix epoch timestamps.
]##


import strutils, macros, typetraits, logging, options
import ndb/sqlite

import sqlite/[rowutils, sqlgen], objutils, typedefutils


export strutils, logging, options
export sqlite
export rowutils, sqlgen, objutils


template genWithDb(connection, user, password, database: string,
                   tableSchemas, dropTableQueries: openArray[SqlQuery]): untyped {.dirty.} =
  ## Generate ``withDb`` templates.

  template withCustomDb*(customConnection, customUser, customPassword, customDatabase: string,
                         body: untyped): untyped {.dirty.} =
    ##[ A wrapper for actions that require custom DB connection, i.e. not the one defined in ``db``.
    Defines CRUD procs to work with the DB, as well as ``createTables`` and ``dropTables`` procs.

    Aforementioned procs and procs defined in a ``db`` block can be used only
    in  a ``withDb`` block.
    ]##

    block:
      let dbConn = open(customConnection, customUser, customPassword, customDatabase)

      template dropTables() {.used.} =
        ## Drop tables for all types in all type sections under ``db`` macro.

        for dropTableQuery in dropTableQueries:
          debug dropTableQuery

          dbConn.exec sql dropTableQuery

      template createTables(force = false) {.used.} =
        ##[ Create tables for all types in all type sections under ``db`` macro.

        If ``force`` is ``true``, drop tables beforehand.
        ]##

        if force:
          dropTables()

        for tableSchema in tableSchemas:
          debug tableSchema

          dbConn.exec sql tableSchema

      template insert(obj: var object, force = false) {.used.} =
        ##[ Insert object instance as a record into DB.The object's id is updated after
        the insertion.

        By default, readonly fields are not inserted. Use ``force=true`` to insert all fields.
        ]##

        let
          insertQuery = genInsertQuery(obj, force)
          params = obj.toRow(force)

        debug insertQuery, " <- ", params.join(", ")

        obj.id = dbConn.insertID(insertQuery, params).int

      template getOne(obj: var object, cond: string, params: varargs[DbValue, dbValue]) {.used.} =
        ##[ Read a record from DB by condition and store it into an existing object instance.

        If multiple records are found, return the first one.
        ]##

        let getOneQuery = genGetOneQuery(obj, cond)

        debug getOneQuery, " <- ", params.join(", ")

        let row = dbConn.getRow(getOneQuery, params)

        if row.isNone():
          raise newException(KeyError, "Record by condition '$#' with params '$#' not found." %
                             [cond, params.join(", ")])

        get(row).to(obj)

      proc getOne(T: typedesc, cond: string, params: varargs[DbValue, dbValue]): T {.used.} =
        ##[ Read a record from DB by condition into a new object instance.

        If multiple records are found, return the first one.
        ]##

        result.getOne(cond, params)

      template getOne(obj: var object, id: int) {.used.} =
        ## Read a record from DB by id and store it into an existing object instance.

        let getOneQuery = genGetOneQuery(obj, "id=?")

        debug getOneQuery, " <- ", $id

        let row = dbConn.getRow(getOneQuery, id)

        if row.isNone():
          raise newException(KeyError, "Record with id=$# not found." % $id)

        get(row).to(obj)

      proc getOne(T: typedesc, id: int): T {.used.} =
        ## Read a record from DB by id into a new object instance.

        result.getOne(id)

      proc getMany(objs: var seq[object], limit: int, offset = 0,
                   cond = "1", params: varargs[DbValue, dbValue]) {.used.} =
        ##[ Read ``limit`` records with ``offset`` from DB into an existing open array of objects.

        Filter using ``cond`` condition.
        ]##

        if len(objs) == 0: return

        let
          getManyQuery = genGetManyQuery(objs[0], cond)
          params = @params & @[?min(limit, len(objs)), ?offset]

        debug getManyQuery, " <- ", params.join(", ")

        let rows = dbConn.getAllRows(getManyQuery, params)

        rows.to(objs)

      proc getMany(T: typedesc, limit: int, offset = 0,
                   cond = "1", params: varargs[DbValue, dbValue]): seq[T] {.used.} =
        ##[ Read ``limit`` records  with ``offset`` from DB into a sequence of objects,
        create the sequence on the fly.

        Filter using ``cond`` condition.
        ]##

        result.setLen limit
        result.getMany(limit, offset, cond, params)

      template update(obj: object, force = false) {.used.} =
        ##[ Update DB record with object field values.

        By default, readonly fields are not updated. Use ``force=true`` to update all fields.
        ]##

        let
          updateQuery = genUpdateQuery(obj, force)
          params = obj.toRow(force) & ?obj.id

        debug updateQuery, " <- ", params.join(", ")

        dbConn.exec(updateQuery, params)

      template delete(obj: var object) {.used.} =
        ## Delete a record in DB by object's id. The id is set to 0 after the deletion.

        let deleteQuery = genDeleteQuery(obj)

        debug deleteQuery, " <- ", $obj.id

        dbConn.exec(deleteQuery, obj.id)

        obj.id = 0

      try:
        let foreignKeyQuery {.genSym.} = sql "PRAGMA foreign_keys = ON"
        debug foreignKeyQuery
        dbConn.exec foreignKeyQuery
        body
      finally: dbConn.close()

  template withDb*(body: untyped): untyped {.dirty.} =
    ##[ A wrapper for actions that require DB connection. Defines CRUD procs to work with the DB,
    as well as ``createTables`` and ``dropTables`` procs.

      Aforementioned procs and procs defined in a ``db`` block can be used only
      in  a ``withDb`` block.
    ]##

    withCustomDb(connection, user, password, database):
      body

macro dbTypes*(body: untyped): untyped =
  result = newStmtList()

  for node in body:
    expectKind(node, nnkTypeSection)
    result.add ensureForeignKeys(ensureIdFields(node))

macro dbFromTypes*(connection, user, password, database: string,
                   types: openArray[typedesc]): untyped =
  ##[ DB models definition. Models are defined as regular Nim objects in regular ``type`` sections.

  ``connection``, ``user``, ``password``, ``database`` are the same args accepted
  by a standard ``dbConn`` instance.

  ``types`` is a list of predefined types to create table schemas from.

  The macro generates ``withDb`` template that wraps all DB interations.
  ]##

  var dbObjReprs: seq[ObjRepr]

  for typ in types:
    let objRepr = getImpl(typ).toObjRepr()

    if "id" notin objRepr.fieldNames:
      error "Type '$#' is missing 'id' field. Put it under 'ensureIdFields' macro." % $typ

    dbObjReprs.add getImpl(typ).toObjRepr()

  result = getAst genWithDb(connection, user, password, database,
                            genTableSchemas(dbObjReprs), genDropTableQueries(dbObjReprs))

macro db*(connection, user, password, database: string, body: untyped): untyped =
  ##[ DB models definition. Models are defined as regular Nim objects in regular ``type`` sections.

  ``connection``, ``user``, ``password``, ``database`` are the same args accepted
  by a standard ``dbConn`` instance.

  The macro generates ``withDb`` template that wraps all DB interations.
  ]##

  result = newStmtList()

  var dbObjReprs: seq[ObjRepr]

  for node in body:
    if node.kind == nnkTypeSection:
      let typeSection = ensureForeignKeys(ensureIdFields(node))

      result.add typeSection

      for typeDef in typeSection:
        dbObjReprs.add typeDef.toObjRepr()

    else:
      result.add node

  let withDbNode = getAst genWithDb(connection, user, password, database,
                                    genTableSchemas(dbObjReprs), genDropTableQueries(dbObjReprs))

  result.insert(0, withDbNode)
