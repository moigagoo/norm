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
  ObjDef = object
    name: NimNode
    fields: seq[Field]
    pragmas: seq[Pragma]


macro foo(body: untyped): untyped =
  for typeSection in body:
    var objDef = ObjDef()

    for typeDef in typeSection:
      expectKind(typeDef[0], {nnkIdent, nnkPragmaExpr})

      case typeDef[0].kind
      of nnkIdent:
        objDef.name = typeDef[0]
      of nnkPragmaExpr:
        objDef.name = typeDef[0][0]
        for pragmaDef in typeDef[0][1]:
          objDef.pragmas.add case pragmaDef.kind
          of nnkIdent: Pragma(kind: pkFlag, name: pragmaDef)
          of nnkExprColonExpr: Pragma(kind: pkKval, name: pragmaDef[0], value: pragmaDef[1])
          else: Pragma()
      else: discard

      expectKind(typeDef[2], nnkObjectTy)

      for fieldDef in typeDef[2][2]:
        echo treeRepr fieldDef

      # echo treeRepr typeDef
      echo objDef


foo:
  type
    User {.table: "users", shmable.} = object
      name: string
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
