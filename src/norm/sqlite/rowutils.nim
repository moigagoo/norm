##[

######################################
SQL Row to Nim Object Conversion Procs
######################################

This module implements ``to`` and ``toRow`` proc families for row to object and object to row conversion respectively.

``Row`` is a sequence of ``ndb.DbValue``, which allows to store ``options.none`` values as ``NULL`` and vice versa.
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

  runnableExamples:
    import times, sugar
    import ndb/sqlite

    proc parseDateTime(dbv: DbValue): DateTime = dbv.s.parse("yyyy-MM-dd HH:mm:sszz", utc())

    type
      Example = object
        intField: int
        strField: string
        floatField: float
        boolField: bool
        dtField {.parser: parseDateTime.}: DateTime
        tsField: DateTime

    let row = @[
      ?123,
      ?"foo",
      ?123.321,
      ?1,
      ?"2019-01-21 15:03:21+04",
      ?1566243173
    ]

    var example = Example(dtField: now(), tsField: now())
    row.to(example)

    doAssert example.intField == 123
    doAssert example.strField == "foo"
    doAssert example.floatField == 123.321
    doAssert example.boolField == true
    doAssert example.dtField == "2019-01-21 15:03:21+04".parse("yyyy-MM-dd HH:mm:sszz", utc())
    doAssert example.tsField == "2019-08-19 23:32:53+04".parse("yyyy-MM-dd HH:mm:sszz", utc())

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
      raise newException(ValueError, "Parser for " & $typeof(value) & "is undefined.")

    inc i

template to*(rows: openArray[Row], objs: var seq[object]) =
  ##[ Convert a open array of rows into an existing sequence of objects.

  If the number of rows is higher than the number of objects, extra rows are ignored.

  If the number of objects is higher, unused objects are trimmed away.
  ]##

  runnableExamples:
    import times, sugar
    import ndb/sqlite

    proc parseDateTime(dbv: DbValue): DateTime = dbv.s.parse("yyyy-MM-dd HH:mm:sszz", utc())

    type
      Example = object
        intField: int
        strField: string
        floatField: float
        boolField: bool
        dtField {.parser: parseDateTime.}: DateTime

    let rows = @[
      @[
        ?123,
        ?"foo",
        ?123.321,
        ?1,
        ?"2019-01-21 15:03:21+04"
      ],
      @[
        ?456,
        ?"bar",
        ?456.654,
        ?0,
        ?"2019-02-22 16:14:32+04"
      ],
      @[
        ?789,
        ?"baz",
        ?789.987,
        ?1,
        ?"2019-03-23 17:25:43+04"
      ]
    ]

    var examples = @[
      Example(dtField: now()),
      Example(dtField: now()),
      Example(dtField: now()),
      Example(dtField: now())
    ]

    rows.to(examples)

    doAssert examples[0].intField == 123
    doAssert examples[1].strField == "bar"
    doAssert examples[2].floatField == 789.987
    doAssert examples[0].boolField == true
    doAssert examples[0].dtField == "2019-01-21 15:03:21+04".parse("yyyy-MM-dd HH:mm:sszz", utc())

  objs.setLen min(len(rows), len(objs))

  for i in 0..high(objs):
    rows[i].to(objs[i])

proc to*(row: Row, T: typedesc): T =
  ##[ Instantiate object with type ``T`` with values from ``row``. String values from row are converted into types of the respective object fields.

  Use this proc if the object fields have default values and do not require initialization, e.g. ``int``, ``string``, ``float``.

  If fields require initialization, for example, ``times.DateTime``, use template ``to``. It converts a row to a existing object instance.
  ]##

  runnableExamples:
    import ndb/sqlite

    type
      Example = object
        intField: int
        strField: string
        floatField: float
        boolField: bool

    let
      row = @[?123, ?"foo", ?123.321, ?0]
      obj = row.to(Example)

    doAssert obj.intField == 123
    doAssert obj.strField == "foo"
    doAssert obj.floatField == 123.321
    doAssert obj.boolField == false

  row.to(result)

proc to*(rows: openArray[Row], T: typedesc): seq[T] =
  ##[ Instantiate a sequence of objects with type ``T`` with values from ``rows``. String values from each row are converted into types of the respective object fields.

  Use this proc if the object fields have default values and do not require initialization, e.g. ``int``, ``string``, ``float``.

  If fields require initialization, for example, ``times.DateTime``, use template ``to``. It converts an open array of rows to an existing object instance openArray.
  ]##

  runnableExamples:
    import ndb/sqlite

    type
      Example = object
        intField: int
        strField: string
        floatField: float
        boolField: bool

    let
      rows = @[
        @[?123, ?"foo", ?123.321, ?1],
        @[?456, ?"bar", ?456.654, ?0],
        @[?789, ?"baz", ?789.987, ?1]
      ]
      examples = rows.to(Example)

    doAssert examples[0].intField == 123
    doAssert examples[1].strField == "bar"
    doAssert examples[2].floatField == 789.987
    doAssert examples[0].boolField == true

  result.setLen len(rows)

  rows.to(result)

proc toRow*(obj: object, force = false): Row =
  ##[ Convert an object into row, i.e. sequence of strings.

  If a custom formatter is provided for a field, it is used for conversion, otherwise `$` is invoked.
  ]##

  runnableExamples:
    import strutils, times, ndb/sqlite

    type
      Example = object
        intField: int
        strField{.formatIt: ?it.toLowerAscii().}: string
        floatField: float
        boolField: bool
        tsField: DateTime

    let
      example = Example(
        intField: 123,
        strField: "Foo",
        floatField: 123.321,
        boolField: true,
        tsField: "2019-08-19 23:32:53+04".parse("yyyy-MM-dd HH:mm:sszz", utc())
      )
      row = example.toRow()

    doAssert row[0].i == 123
    doAssert row[1].s == "foo"
    doAssert row[2].f == 123.321
    doAssert row[3].i == 1
    doAssert row[4].i == 1566243173

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

  runnableExamples:
    import strutils, sequtils, ndb/sqlite

    type
      Example = object
        intField: int
        strField{.formatIt: ?it.toLowerAscii().}: string
        floatField: float
        boolField: bool

    let
      examples = @[
        Example(intField: 123, strField: "Foo", floatField: 123.321, boolField: true),
        Example(intField: 456, strField: "Bar", floatField: 456.654, boolField: false),
        Example(intField: 789, strField: "Baz", floatField: 789.987, boolField: true)
      ]
      rows = examples.toRows()

    doAssert rows[0][0].i == 123
    doAssert rows[1][1].s == "bar"
    doAssert rows[2][2].f == 789.987
    doAssert rows[1][3].i == 0

  objs.mapIt(it.toRow(force))
