##[

##################
PostgreSQL Backend
##################

The following Nim types are converted automatically:

================== ====================
Nim Type           SQLite Type
================== ====================
``int``            ``INTEGER``
``string``         ``TEXT``
``float``          ``REAL``
``bool``           ``BOOLEAN``
``DateTime``       ``TIMESTAMP WITH TIME ZONE``
================== ====================
]##


import strutils, macros, typetraits, logging
import db_postgres

import postgres/[rowutils, sqlgen], objutils, typedefutils


export strutils, logging
export db_postgres
export rowutils, sqlgen, objutils


template genWithDb(connection, user, password, database: string, dbTypeNames: openArray[string]): untyped {.dirty.} =
  ## Generate ``withDb`` template.

  template withCustomDb*(customConnection, customUser, customPassword, customDatabase: string,
                         body: untyped): untyped {.dirty.} =
    ##[ A wrapper for actions that require custom DB connection, i.e. not the one defined in ``db``.
    Defines CRUD procs to work with the DB, as well as ``createTables`` and ``dropTables`` procs.

    Aforementioned procs and procs defined in a ``db`` block can be used only
    in  a ``withDb`` block.
    ]##

    block:
      let dbConn = open(customConnection, customUser, customPassword, customDatabase)

      template dropTable(T: typedesc) {.used.} =
        let dropTableQuery = genDropTableQuery(T.getTable())

        debug dropTableQuery

        dbConn.exec dropTableQuery

      macro dropTables(): untyped {.used.} =
        ## Drop tables for all types in all type sections under ``db`` macro.


        result = newStmtList()

        for dbTypeName in dbTypeNames:
          result.add newCall(
            newDotExpr(
              ident dbTypeName,
              bindSym "dropTable"
            )
          )

      template createTable(T: typedesc, force = false) {.used.} =
        ## Create table for a type. If ``force`` is ``true``, drop the table beforehand.

        if force:
          T.dropTable()

        let createTableQuery = genCreateTableQuery(T.getTable(), genTableSchema(T))

        debug createTableQuery

        dbConn.exec createTableQuery

      macro createTables(force = false) {.used.} =
        ##[ Create tables for all types in all type sections under ``db`` macro.

        If ``force`` is ``true``, drop tables beforehand.
        ]##

        result = newStmtList()

        for dbTypeName in dbTypeNames:
          result.add newCall(
            newDotExpr(
              ident dbTypeName,
              bindSym "createTable"
            ),
            newNimNode(nnkExprEqExpr).add(
              ident "force",
              force
            )
          )

      template addColumn(field: typedesc) {.used.} =
        ## Add column to a table schema from a new object field.

        let addColQuery = genAddColQuery(field)

        debug addColQuery

        dbConn.exec sql addColQuery

      template removeColumns(T: typedesc) {.used.} =
        ## Update table schema after removing object fields.

        let
          tmpTableName = "tmp" & T.getTable()
          createTmpTableQuery = genCreateTableQuery(tmpTableName, genTableSchema(T))
          copyQuery = genCopyQuery(T, tmpTableName)
          renameTmpTableQuery = genRenameTableQuery(tmpTableName, T.getTable())

        debug createTmpTableQuery
        dbConn.exec createTmpTableQuery

        debug copyQuery
        dbConn.exec copyQuery

        T.dropTable()

        debug renameTmpTableQuery
        dbConn.exec renameTmpTableQuery

      template renameColumnFrom(field: typedesc, oldName: string) {.used.} =
        ##[ Update column name in a table schema after an object field gets renamed or its ``dbCol`` pragma value is updated.

        The old column name must be provided so that Norm would be able to find the existing column to rename.
        ]##

        let renameColQuery = genRenameColQuery(field, oldName)

        debug renameColQuery

        dbConn.exec sql renameColQuery

      template renameTableFrom(T: typedesc, oldName: string) {.used.} =
        ##[ Update table name in a table schema after an object gets renamed or its ``table`` pragma value is updated.

        The old table name must be provided so that Norm would be able to find the existing table to rename.
        ]##

        let renameTableQuery = genRenameTableQuery(oldName, T.getTable())

        debug renameTableQuery

        dbConn.exec renameTableQuery

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

      template getOne(obj: var object, cond: string, params: varargs[string, `$`]) {.used.} =
        ##[ Read a record from DB by condition and store it into an existing object instance.

        If multiple records are found, return the first one.
        ]##

        let getOneQuery = genGetOneQuery(obj, cond)

        debug getOneQuery, " <- ", params.join(", ")

        let row = dbConn.getRow(getOneQuery, params)

        if row.isEmpty():
          raise newException(KeyError, "Record by condition '$#' with params '$#' not found." %
                             [cond, params.join(", ")])

        row.to(obj)

      proc getOne(T: typedesc, cond: string, params: varargs[string, `$`]): T {.used.} =
        ##[ Read a record from DB by condition into a new object instance.

        If multiple records are found, return the first one.
        ]##

        result.getOne(cond, params)

      template getOne(obj: var object, id: int) {.used.} =
        ## Read a record from DB and store it into an existing object instance.

        let getOneQuery = genGetOneQuery(obj, "id=?")

        debug getOneQuery, " <- ", $id

        let row = dbConn.getRow(getOneQuery, id)

        if row.isEmpty():
          raise newException(KeyError, "Record with id=$# not found." % $id)

        row.to(obj)

      proc getOne(T: typedesc, id: int): T {.used.} =
        ## Read a record from DB into a new object instance.

        result.getOne(id)

      proc getMany(objs: var seq[object], limit: int, offset = 0,
                   cond = "TRUE", params: varargs[string, `$`]) {.used.} =
        ##[ Read ``limit`` records with ``offset`` from DB into an existing open array of objects.

        Filter using ``cond`` condition.
        ]##

        if len(objs) == 0: return

        let
          getManyQuery = genGetManyQuery(objs[0], cond)
          params = @params & @[$min(limit, len(objs)), $offset]

        debug getManyQuery, " <- ", params.join(", ")

        let rows = dbConn.getAllRows(getManyQuery, params)

        rows.to(objs)

      proc getMany(T: typedesc, limit: int, offset = 0,
                   cond = "TRUE", params: varargs[string, `$`]): seq[T] {.used.} =
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
          params = obj.toRow(force) & $obj.id

        debug updateQuery, " <- ", params.join(", ")

        dbConn.exec(updateQuery, params)

      template delete(obj: var object) {.used.} =
        ## Delete a record in DB by object's id. The id is set to 0 after the deletion.

        let deleteQuery = genDeleteQuery(obj)

        debug deleteQuery, " <- ", $obj.id

        dbConn.exec(deleteQuery, obj.id)

        obj.id = 0

      try:
        body

      finally:
        dbConn.close()

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
    result.add ensureIdFields(node)

macro dbFromTypes*(connection, user, password, database: string,
                   types: openArray[typedesc]): untyped =
  ##[ DB models definition. Models are defined as regular Nim objects in regular ``type`` sections.

  ``connection``, ``user``, ``password``, ``database`` are the same args accepted
  by a standard ``dbConn`` instance.

  ``types`` is a list of predefined types to create table schemas from.

  The macro generates ``withDb`` template that wraps all DB interations.
  ]##

  var dbTypeNames: seq[string]

  for typ in types:
    let objRepr = typ.getImpl().toObjRepr()

    if "id" notin objRepr.fieldNames:
      error "Type '$#' is missing 'id' field. Wrap it with 'dbTypes' macro." % $typ

    dbTypeNames.add objRepr.signature.name

  result = getAst genWithDb(connection, user, password, database, dbTypeNames)

macro db*(connection, user, password, database: string, body: untyped): untyped =
  ##[ DB models definition. Models are defined as regular Nim objects in regular ``type`` sections.

  ``connection``, ``user``, ``password``, ``database`` are the same args accepted
  by a standard ``dbConn`` instance.

  The macro generates ``withDb`` template that wraps all DB interations.
  ]##

  result = newStmtList()

  var dbTypeNames: seq[string]

  for node in body:
    if node.kind == nnkTypeSection:
      let typeSection = node.ensureIdFields()

      result.add typeSection

      for typeDef in typeSection:
        dbTypeNames.add typeDef.toObjRepr().signature.name

    else:
      result.add node

  let withDbNode = getAst genWithDb(connection, user, password, database, dbTypeNames)

  result.insert(0, withDbNode)
