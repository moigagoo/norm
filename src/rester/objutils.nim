import macros


type
  PragmaKind = enum
    pkFlag, pkKval
  Pragma = object
    name: NimNode
    case kind: PragmaKind
    of pkFlag: discard
    of pkKval: value: NimNode
  Field = object
    name: NimNode
    typ: NimNode
    pragmas: seq[Pragma]
  Object = object
    name: NimNode
    fields: seq[Field]
    pragmas: seq[Pragma]


proc getPragmas(pragmaDefs: NimNode): seq[Pragma] =
  for pragmaDef in pragmaDefs:
    result.add case pragmaDef.kind
      of nnkIdent: Pragma(kind: pkFlag, name: pragmaDef)
      of nnkExprColonExpr: Pragma(kind: pkKval, name: pragmaDef[0], value: pragmaDef[1])
      else: Pragma()

proc parseObjDef*(typeDef: NimNode): Object =
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

macro foo(body: untyped): untyped =
  for typeSection in body:
    for typeDef in typeSection:
      let obj = parseObjDef(typeDef)
      echo obj.name, ":"
      for field in obj.fields:
        echo "\t", field.name, ": ", field.typ, ", ", field.pragmas.len, " pragmas."


foo:
  type
    User {.table: "users", shmable.} = object
      name {.protected, parseIt: it.toLowerAscii() .}: string
      age: int
    Book = object
      title: string


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
