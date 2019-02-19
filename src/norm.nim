import strutils, macros
import typetraits
import db_sqlite

import chronicles

import norm / [objutils, rowutils]


template pk* {.pragma.}
  ## Mark field as primary key. The special field ``id`` is mark with ``pk`` by default.

template ro* {.pragma.}
  ##[ Mark field as read-only.

  Read-only fields are ignored in ``insert`` and ``update`` unless ``force`` is passed.

  Use for fields that are populated automatically by the DB: ids, timestamps, and so on.
  The special field ``id`` is mark with ``pk`` by default.
  ]##

template fk*(val: untyped) {.pragma.}
  ##[ Mark field as foreign key another type. ``val`` is either a type or a "type.field"
  expression. If a type is provided, its ``id`` field is referenced.
  ]##

template dbType*(val: string) {.pragma.}
  ## DB native type to use in table schema.

template default*(val: string) {.pragma.}
  ## Default value for the DB column.

template notNull* {.pragma.}
  ## Add ``NOT NULL`` constraint.

template check*(val: string) {.pragma.}
  ## Add a ``CHECK <CONDITION>}`` constraint.

template table*(val: string) {.pragma.}
  ## Set table name.

proc getTable*(objRepr: ObjRepr): string =
  ##[ Get the name of the DB table for the given object representation:
  ``table`` pragma value if it exists or lowercased type name otherwise.
  ]##

  result = objRepr.signature.name.toLowerAscii()

  for prag in objRepr.signature.pragmas:
    if prag.name == "table" and prag.kind == pkKval:
      return $prag.value

proc getDbType(fieldRepr: FieldRepr): string =
  ## SQLite-specific mapping from Nim types to SQL data types.

  result = case $fieldRepr.typ
  of "int": "INTEGER"
  of "string": "TEXT"
  of "float": "REAL"
  else: "TEXT"

  for prag in fieldRepr.signature.pragmas:
    if prag.name == "dbType" and prag.kind == pkKval:
      return $prag.value

proc genColStmt(fieldRepr: FieldRepr, dbObjReprs: openarray[ObjRepr]): string =
  ## Generate SQL column statement for a field representation.

  result.add fieldRepr.signature.name
  result.add " "
  result.add getDbType(fieldRepr)

  for prag in fieldRepr.signature.pragmas:
    if prag.name == "pk" and prag.kind == pkFlag:
      result.add " PRIMARY KEY"
    elif prag.name == "notNull" and prag.kind == pkFlag:
      result.add " NOT NULL"
    elif prag.name == "check" and prag.kind == pkKval:
      result.add " CHECK $#" % $prag.value
    elif prag.name == "default" and prag.kind == pkKval:
      result.add " DEFAULT $#" % $prag.value
    elif prag.name == "fk" and prag.kind == pkKval:
      expectKind(prag.value, {nnkIdent, nnkDotExpr})

      result.add case prag.value.kind
      of nnkIdent:
        ", FOREIGN KEY ($#) REFERENCES $# (id)" % [fieldRepr.signature.name,
                                                    dbObjReprs.getByName($prag.value).getTable()]
      of nnkDotExpr:
        ", FOREIGN KEY ($#) REFERENCES $# ($#)" % [fieldRepr.signature.name,
                                                    dbObjReprs.getByName($prag.value[0]).getTable(),
                                                    $prag.value[1]]
      else: ""

proc genTableSchema(dbObjRepr: ObjRepr, dbObjReprs: openarray[ObjRepr]): string =
  ## Generate table schema for an object representation.

  result.add "CREATE TABLE $# (\n" % dbObjRepr.getTable()

  var columns: seq[string]

  for field in dbObjRepr.fields:
    columns.add "\t$#" % genColStmt(field, dbObjReprs)

  result.add columns.join(",\n")
  result.add "\n)"

proc genTableSchemas*(dbObjReprs: openarray[ObjRepr]): seq[string] =
  ## Generate DB schema for a list of object representations.

  for dbObjRepr in dbObjReprs:
    result.add genTableSchema(dbObjRepr, dbObjReprs)

proc genDropTableQueries*(dbObjReprs: seq[ObjRepr]): seq[string] =
  ## Generate ``DROP TABLE`` statements for a list of object representations.

  for dbObjRepr in dbObjReprs:
    result.add "DROP TABLE IF EXISTS $#" % dbObjRepr.getTable()

proc genInsertQuery*(obj: object, force: bool): SqlQuery =
  var fields: seq[string]

  for field, _ in obj.fieldPairs:
    if force or not obj[field].hasCustomPragma(ro):
      fields.add field

  result = sql "INSERT INTO ? ($#) VALUES ($#)" % [fields.join(", "),
                                                    '?'.repeat(fields.len).join(", ")]

proc genGetOneQuery*(obj: object): SqlQuery =
  sql "SELECT $# FROM ? WHERE id = ?" % obj.fieldNames.join(", ")

proc genGetManyQuery*(obj: object): SqlQuery =
  sql "SELECT $# FROM ? LIMIT ? OFFSET ?" % obj.fieldNames.join(", ")

proc getTable*(T: type): string =
  ##[ Get the name of the DB table for the given type: ``table`` pragma value if it exists
  or lowercased type name otherwise.
  ]##

  when T.hasCustomPragma(table): T.getCustomPragmaVal(table)
  else: T.name.toLowerAscii()

template genMakeDbTmpl(connection, user, password, database: string,
                        tableSchemas, dropTableQueries: openarray[string],
                        dbOthers: NimNode): untyped {.dirty.} =
  ## Generate ``withDb`` template.

  template withDb*(body: untyped): untyped {.dirty.} =
    ##[ A wrapper for actions that require DB connection. Defines CRUD procs to work with the DB,
    as well as ``createTables`` and ``dropTables`` procs.

      Aforementioned procs and procs defined in a ``db`` block can be used only
      in  a ``withDb`` block.
    ]##

    block:
      let dbConn = open(connection, user, password, database)

      template dropTables() =
        ## Drop tables for all types in all type sections under ``db`` macro.

        for dropTableQuery in dropTableQueries:
          debug "Drop table", query = dropTableQuery
          dbConn.exec sql dropTableQuery

      template createTables(force = false) =
        ##[ Create tables for all types in all type sections under ``db`` macro.

        If ``force`` is ``true``, drop tables beforehand.
        ]##

        if force:
          dropTables()

        for tableSchema in tableSchemas:
          debug "Create table", query = tableSchema
          dbConn.exec sql tableSchema

      template insert(obj: var object, force = false) =
        ##[ Insert object instance as a record into DB.The object's id is updated after
        the insertion.

        By default, readonly fields are not inserted. Use ``force=true`` to insert all fields.
        ]##

        var values: seq[string]

        for _, value in obj.fieldPairs:
          when force or not obj[_].hasCustomPragma(ro):
            values.add $value

        obj.id = dbConn.insertID(genInsertQuery(obj, force), type(obj).getTable() & values).int

      template update(obj: object, force = false) =
        ##[ Update DB record with object field values.

        By default, readonly fields are not updated. Use ``force=true`` to update all fields.
        ]##

        var fieldsWithPlaceholders, values: seq[string]

        for field, value in obj.fieldPairs:
          when force or not obj[field].hasCustomPragma(ro):
            fieldsWithPlaceholders.add field & " = ?"
            values.add $value

        let
          query = sql "UPDATE ? SET $# WHERE id = ?" % fieldsWithPlaceholders.join(", ")
          params = type(obj).getTable() & values & $obj.id

        dbConn.exec(query, params)

      template getOne(obj: var object, id: int) =
        ## Read a record from DB and store it into an existing object instance.

        let
          params = [type(obj).getTable(), $id]
          row = dbConn.getRow(genGetOneQuery(obj), params)

        if row.isEmpty():
          raise newException(KeyError, "Record with id=$# not found." % $id)

        row.to(obj)

      proc getOne(T: type, id: int): T =
        ## Read a record from DB into a new object instance.

        result.getOne(id)

      proc getMany(objs: var seq[object], limit: int,  offset = 0) =
        ## Read ``limit`` records from DB into an existing open array of objects with ``offset``.

        if len(objs) == 0: return

        let
          params = [type(objs[0]).getTable(), $min(limit, len(objs)), $offset]
          rows = dbConn.getAllRows(genGetManyQuery(objs[0]), params)

        rows.to(objs)

      proc getMany(T: type, limit: int, offset = 0): seq[T] =
        ##[ Read ``limit`` records from DB into a sequence of objects with ``offset``,
        create the sequence on the fly.
        ]##

        result.setLen limit
        result.getMany(limit, offset)

      template delete(obj: var object) =
        ## Delete a record in DB by object's id. The id is set to 0 after the deletion.

        dbConn.exec(sql"DELETE FROM ? WHERE id = ?", type(obj).getTable(), obj.id)
        obj.id = 0

      dbOthers

      try: body
      finally: dbConn.close()

proc ensureIdFields(typeSection: NimNode): NimNode =
  ## Check if ``id`` field is in the object definition, insert it if it's not.

  result = newNimNode(nnkTypeSection)

  for typeDef in typeSection:
    var objRepr = typeDef.toObjRepr()

    if "id" notin objRepr.fieldNames:
      let idField = FieldRepr(
        signature: SignatureRepr(
          name: "id",
          exported: true,
          pragmas: @[
            PragmaRepr(name: "pk", kind: pkFlag),
            PragmaRepr(name: "ro", kind: pkFlag)
          ]
        ),
        typ: ident "int"
      )
      objRepr.fields.insert(idField, 0)

    result.add objRepr.toTypeDef()

macro db*(backend: untyped, connection, user, password, database: string, body: untyped): untyped =
  ##[ DB models definition. Models are defined as regular Nim objects in a regular ``type`` section.

  ``backend`` is one of ``db_sqlite`` or ``db_postgres``.

  ``connection``, ``user``, ``password``, ``database`` are the same args accepted
  by a standard ``dbConn`` instance.

  The macro generates ``withDb`` template that can be used to query the DB.

  Additional pragmas are used to finetune DB and tables.
  ]##

  result = newStmtList()

  var
    dbTypeSections = newStmtList()
    dbObjReprs: seq[ObjRepr]
    dbOthers = newStmtList()

  for node in body:
    if node.kind == nnkTypeSection:
      dbTypeSections.add node.ensureIdFields()
    else:
      dbOthers.add node

  for typeSection in dbTypeSections:
    for typeDef in typeSection:
      dbObjReprs.add typeDef.toObjRepr()

  result.add getAst genMakeDbTmpl(connection, user, password, database,
                                  genTableSchemas(dbObjReprs), genDropTableQueries(dbObjReprs),
                                  dbOthers)
  result.add dbTypeSections
