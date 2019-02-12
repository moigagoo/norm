import macros


type
  PragmaKind* = enum
    ##[ There are two kinds of pragmas: flags and key-value pairs:

      .. code-block:: nim

        type Example {.flag, key: value .} = object
    ]##

    pkFlag, pkKval

  PragmaRepr* = object
    ##[ A container for pragma definition components.

    For flag pragmas, only the pragma name is stored. For key-value pragmas,
    name and value are stored.
    ]##

    name*: NimNode
    case kind*: PragmaKind
    of pkFlag: discard
    of pkKval: value*: NimNode

  Signature* = object
    ##[ Part of an object or field definition that contains:
      - name
      - exported flag
      - pragmas
    ]##

    name*: NimNode
    exported*: bool
    pragmas*: seq[PragmaRepr]

  FieldRepr* = object
    ## Object field representation: signature + type.

    signature: Signature
    typ*: NimNode

  ObjRepr* = object
    ## Object representation: signature + fields.

    signature: Signature
    fields*: seq[FieldRepr]

proc toPragmaReprs(pragmaDefs: NimNode): seq[PragmaRepr] =
  ## Parse an ``nnkPragma`` node into a sequence of ``PragmaRepr`s.

  expectKind(pragmaDefs, nnkPragma)

  for pragmaDef in pragmaDefs:
    result.add case pragmaDef.kind
      of nnkIdent: PragmaRepr(kind: pkFlag, name: pragmaDef)
      of nnkExprColonExpr: PragmaRepr(kind: pkKval, name: pragmaDef[0], value: pragmaDef[1])
      else: PragmaRepr()

proc parseSignature(def: NimNode): Signature =
  ## Parse signature from an object or field definition node.

  expectKind(def[0], {nnkIdent, nnkPostfix, nnkPragmaExpr})

  case def[0].kind
    of nnkIdent:
      result.name = def[0]
    of nnkPostfix:
      result.name = def[0][1]
      result.exported = true
    of nnkPragmaExpr:
      expectKind(def[0][0], {nnkIdent, nnkPostfix})
      case def[0][0].kind
      of nnkIdent:
        result.name = def[0][0]
      of nnkPostfix:
        result.name = def[0][0][1]
        result.exported = true
      else: discard
      result.pragmas = def[0][1].toPragmaReprs()
    else: discard

proc toObjRepr*(typeDef: NimNode): ObjRepr =
  ## Parse type definition of an object into an ``ObjRepr`` instance.

  result.signature = parseSignature(typeDef)

  expectKind(typeDef[2], nnkObjectTy)

  for fieldDef in typeDef[2][2]:
    var field = FieldRepr()
    field.signature = parseSignature(fieldDef)
    field.typ = fieldDef[1]
    result.fields.add field

proc toDef(signature: Signature): NimNode =
  let title =
    if not signature.exported: signature.name
    else: newNimNode(nnkPostfix).add(ident"*", signature.name)

  if signature.pragmas.len == 0:
    return title
  else:
    var pragmas = newNimNode(nnkPragma)

    for pragma in signature.pragmas:
      pragmas.add case pragma.kind
      of pkFlag: pragma.name
      of pkKval: newColonExpr(pragma.name, pragma.value)

    result = newNimNode(nnkPragmaExpr).add(title, pragmas)

proc toTypeDef*(obj: ObjRepr): NimNode =
  var fieldDefs = newNimNode(nnkRecList)

  for field in obj.fields:
    fieldDefs.add newIdentDefs(field.signature.toDef(), field.typ)

  result = newNimNode(nnkTypeDef).add(
    obj.signature.toDef(),
    newEmptyNode(),
    newNimNode(nnkObjectTy).add(
      newEmptyNode(),
      newEmptyNode(),
      fieldDefs
    )
  )

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
