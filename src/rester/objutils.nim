import macros


type
  PragmaKind* = enum
    pkFlag, pkKval

  Pragma* = object
    ##[ A container for a pragma definition components.

    There are two kinds of pragmas: flags and key-value pairs. For flag pragmas,
    only the pragma name is stored. For key-value pragmas, name and value is stored.

    Components are stored as NimNodes.
    ]##

    name*: NimNode
    case kind*: PragmaKind
    of pkFlag: discard
    of pkKval: value*: NimNode

  Field* = object
    ##[ A container for a single object field definition components:
      - field name
      - field type
      - field pragmas

    Components are stored as NimNodes.
    ]##

    name*: NimNode
    typ*: NimNode
    pragmas*: seq[Pragma]

  Object* = object
    ##[ A container for object definition components:
      - type name
      - type pragmas
      - object fields

    Components are stored as NimNodes.
    ]##

    name*: NimNode
    pragmas*: seq[Pragma]
    fields*: seq[Field]


proc getPragmas(pragmaDefs: NimNode): seq[Pragma] =
  for pragmaDef in pragmaDefs:
    result.add case pragmaDef.kind
      of nnkIdent: Pragma(kind: pkFlag, name: pragmaDef)
      of nnkExprColonExpr: Pragma(kind: pkKval, name: pragmaDef[0], value: pragmaDef[1])
      else: Pragma()

proc parseObjDef*(typeDef: NimNode): Object =
  ## Parse type definition of an object into an ``Object`` instance.

  expectKind(typeDef[0], {nnkIdent, nnkPragmaExpr})

  case typeDef[0].kind
    of nnkIdent:
      result.name = typeDef[0]
    of nnkPragmaExpr:
      result.name = typeDef[0][0]
      result.pragmas = typeDef[0][1].getPragmas()
    else: discard

  expectKind(typeDef[2], nnkObjectTy)

  for fieldDef in typeDef[2][2]:
    expectKind(fieldDef[0], {nnkIdent, nnkPragmaExpr})

    var field = Field()

    case fieldDef[0].kind
      of nnkIdent:
        field.name = fieldDef[0]
      of nnkPragmaExpr:
        field.name = fieldDef[0][0]
        field.pragmas = fieldDef[0][1].getPragmas()
      else: discard
    field.typ = fieldDef[1]

    result.fields.add field

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

proc fieldNames*(obj: object): seq[string] =
  ## Get object's field names as a sequence.

  runnableExamples:
    type
      Example = object
        a: int
        b: float
        c: string

    assert Example().fieldNames == @["a", "b", "c"]

  for field, _ in obj.fieldPairs:
    result.add field
