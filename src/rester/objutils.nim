import macros


macro `[]`*(obj: object, fieldName: string): untyped =
  ## Access object field value by name: ``obj["field"]`` translates to ``obj.field``.

  runnableExamples:
    type
      Example = object
        field: int

    let example = Example(field: 123)

    doAssert example["field"] == example.field

  newDotExpr(obj, newIdentNode(fieldName.strVal))

macro `[]=`*(obj: var object, fieldName: string, value: untyped): untyped =
  ## Set object field value by name: ``obj["field"] = value`` translates to ``obj.field = value``.

  runnableExamples:
    type
      Example = object
        field: int

    var example = Example()

    example["field"] = 321

    doAssert example["field"] == 321

  newAssignment(newDotExpr(obj, newIdentNode(fieldName.strVal)), value)
