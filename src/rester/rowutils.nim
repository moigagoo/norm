import strutils
import sugar
import macros; export macros

import objutils


template parser*(op: untyped) {.pragma.}
  ##[ Pragma to define a parser for an object field.

  ``op`` should be a lambda that accepts ``string`` and returns the object field type.
  The proc is called in ``to`` proc or template to turn a string from row into a typed object field.
  ]##

template formatter*(op: untyped) {.pragma.}
  ##[ Pragma to define a formatter for an object field.

  ``op`` should be a lambda that accepts the object field type and returns ``string``.
  The proc is called in ``toRow`` proc to turn a typed object field into a string within a row.
  ]##

template to*(row: seq[string], obj: var object) =
  ##[ Convert row to a given object instance. String values from row are converted
  into types of the respective object fields.

  If object fields don't require initialization, you may use the proc that instantiates the object
  on the fly. This template though can be safely used for all object kinds.
  ]##

  runnableExamples:
    import times, sugar

    type
      Example = object
        intField: int
        strField: string
        floatField: float
        dtField {.parser: (s: string) => s.parse("yyyy-MM-dd HH:mm:sszzz").}: DateTime

    let row = @["123", "foo", "123.321", "2019-01-21 15:03:21+04:00"]

    var example = Example(dtField: now())

    row.to(example)

    doAssert example.intField == 123
    doAssert example.strField == "foo"
    doAssert example.floatField == 123.321
    doAssert example.dtField == "2019-01-21 15:03:21+04:00".parse("yyyy-MM-dd HH:mm:sszzz")

  var i: int

  for field, value in obj.fieldPairs:
    when obj[field].hasCustomPragma(parser):
      obj[field] = obj[field].getCustomPragmaVal(parser) row[i]
    elif type(value) is string:
      obj[field] = row[i]
    elif type(value) is int:
      obj[field] = parseInt row[i]
    elif type(value) is float:
      obj[field] = parseFloat row[i]
    else:
      raise newException(ValueError, "Parser for $# is undefined." % type(value))

    inc i

proc to*(row: seq[string], T: type): T =
  ##[ Instantiate object with type ``T`` with values from ``row``. String values from row
  are converted into types of the respective object fields.

  Use this proc if the object fields have default values and do not require initialization:
  ``int``, ``string``, ``float``, etc.

  If fields require initialization, for example, ``times.DateTime``, use template ``to``.
  It converts a row to a given object instance.
  ]##

  runnableExamples:
    type
      Example = object
        intField: int
        strField: string
        floatField: float

    let
      row = @["123", "foo", "123.321"]
      obj = row.to(Example)

    doAssert obj.intField == 123
    doAssert obj.strField == "foo"
    doAssert obj.floatField == 123.321

  row.to(result)

proc toRow*(obj: object): seq[string] =
  ##[ Convert an object into row, i.e. sequence of strings.

  If a custom formatter is provided for a field via ``formatter`` pragma, it is used for conversion,
  otherwise `$` is invoked.
  ]##

  runnableExamples:
    type
      Example = object
        intField: int
        strField: string
        floatField: float

    let
      example = Example(intField: 123, strField: "foo", floatField: 123.321)
      row = example.toRow()

    doAssert row[0] == "123"
    doAssert row[1] == "foo"
    doAssert row[2] == "123.321"

  for field, value in obj.fieldPairs:
    when obj[field].hasCustomPragma(formatter):
      result.add obj[field].getCustomPragmaVal(formatter) value
    else:
      result.add $value
