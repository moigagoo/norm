##[

######################################
SQL Row to Nim Object Conversion Procs
######################################

This module implements ``to`` and ``toRow`` proc families for row to object and object to row conversion respectively.

``Row`` is a sequence of ``ndb.DbValue``, which allows to store ``options.none`` values as ``NULL`` and vice versa.
]##

import sequtils, options, times
import sugar
import macros; export macros

import ndb/sqlite

import ../objutils, ../pragmas


template parser*(op: (DbValue) -> any) {.pragma.}
  ##[ Pragma to define a parser for an object field.

  ``op`` should be a proc that accepts ``DbValue`` and returns the object field type.

  The proc is called in ``to`` template to turn a string from row into a typed object field.
  ]##

template parseIt*(op: untyped) {.pragma.}
  ##[ Pragma to define a parse expression for an object field.

  ``op`` should be an expression with ``it`` variable that evaluates to the object field type.

  The expression is invoked in ``to`` template to turn a string from row into a typed object field.
  ]##

template formatter*(op: (any) -> DbValue) {.pragma.}
  ##[ Pragma to define a formatter for an object field.

  ``op`` should be a proc that accepts the object field type and returns ``DbValue``.

  The proc is called in ``toRow`` proc to turn a typed object field into a string within a row.
  ]##

template formatIt*(op: untyped) {.pragma.}
  ##[ Pragma to define a format expression for an object field.

  ``op`` should be an expression with ``it`` variable with the object field type and evaluates to ``DbValue``.

  The expression is invoked in ``toRow`` proc to turn a typed object field into a ``DbValue`` within a row.
  ]##

proc dbValue*(v: bool): DbValue = ?(if v: 1 else: 0)

proc dbValue*(v: DateTime): DbValue = ?v.toTime().toUnix()

template to*(row: Row, obj: var object) =
  ##[ Convert row to an existing object instance. String values from row are converted into types of the respective object fields.

  If object fields don't require initialization, you may use the proc that instantiates the object on the fly. This template though can be safely used for all object kinds.
  ]##

  var i: int

  for field, value in obj.fieldPairs:
    when obj.dot(field).hasCustomPragma(parser):
      obj.dot(field) = obj.dot(field).getCustomPragmaVal(parser).op row[i]
    elif obj.dot(field).hasCustomPragma(parseIt):
      block:
        let it {.inject.} = row[i]
        obj.dot(field) = obj.dot(field).getCustomPragmaVal(parseIt)
    elif typeof(value) is string:
      obj.dot(field) = row[i].s
    elif typeof(value) is int:
      obj.dot(field) = row[i].i.int
    elif typeof(value) is int64:
      obj.dot(field) = row[i].i
    elif typeof(value) is float:
      obj.dot(field) = row[i].f
    elif typeof(value) is bool:
      obj.dot(field) = if row[i].i == 0: false else: true
    elif typeof(value) is DateTime:
      obj.dot(field) = row[i].i.fromUnix().utc()
    elif typeof(value) is Option:
      when typeof(get(value)) is string:
        obj.dot(field) = if row[i].kind == dvkNull: none string else: some row[i].s
      elif typeof(get(value)) is int:
        obj.dot(field) = if row[i].kind == dvkNull: none int else: some row[i].i.int
      elif typeof(get(value)) is float:
        obj.dot(field) = if row[i].kind == dvkNull: none float else: some row[i].f
      elif typeof(get(value)) is bool:
        obj.dot(field) =
          if row[i].kind == dvkNull: none bool
          else: some if row[i].i == 0: false else: true
      elif typeof(get(value)) is DateTime:
        obj.dot(field) =
          if row[i].kind == dvkNull: none DateTime else: some row[i].i.fromUnix().utc()
    else:
      # Workaround "unreachable statement after 'return' statement" error.
      if true:
        raise newException(ValueError, "Parser for " & $typeof(value) & " is undefined.")

    inc i

template to*(rows: openArray[Row], objs: var seq[object]) =
  ##[ Convert a open array of rows into an existing sequence of objects.

  If the number of rows is higher than the number of objects, extra rows are ignored.

  If the number of objects is higher, unused objects are trimmed away.
  ]##

  objs.setLen min(len(rows), len(objs))

  for i in 0..high(objs):
    rows[i].to(objs[i])

proc to*(row: Row, T: typedesc): T =
  ##[ Instantiate object with type ``T`` with values from ``row``. String values from row are converted into types of the respective object fields.

  Use this proc if the object fields have default values and do not require initialization, e.g. ``int``, ``string``, ``float``.

  If fields require initialization, for example, ``times.DateTime``, use template ``to``. It converts a row to a existing object instance.
  ]##

  row.to(result)

proc to*(rows: openArray[Row], T: typedesc): seq[T] =
  ##[ Instantiate a sequence of objects with type ``T`` with values from ``rows``. String values from each row are converted into types of the respective object fields.

  Use this proc if the object fields have default values and do not require initialization, e.g. ``int``, ``string``, ``float``.

  If fields require initialization, for example, ``times.DateTime``, use template ``to``. It converts an open array of rows to an existing object instance openArray.
  ]##

  result.setLen len(rows)

  rows.to(result)

proc toRow*(obj: object, force = false): Row =
  ##[ Convert an object into row, i.e. sequence of strings.

  If a custom formatter is provided for a field, it is used for conversion, otherwise `$` is invoked.
  ]##

  for field, value in obj.fieldPairs:
    if force or not obj.dot(field).hasCustomPragma(ro):
      when obj.dot(field).hasCustomPragma(formatter):
        result.add obj.dot(field).getCustomPragmaVal(formatter).op value
      elif obj.dot(field).hasCustomPragma(formatIt):
        block:
          let it {.inject.} = value
          result.add obj.dot(field).getCustomPragmaVal(formatIt)
      else:
        result.add ?value

proc toRows*(objs: openArray[object], force = false): seq[Row] =
  ##[ Convert an open array of objects into a sequence of rows.

  If a custom formatter is provided for a field, it is used for conversion, otherwise `$` is invoked.
  ]##

  objs.mapIt(it.toRow(force))
