## Macros to convert between objects and ``Row`` instances.

import macros, sugar

import strutils
export strutils

from db_sqlite import Row
from db_postgres import Row
from db_mysql import Row


type Row = db_sqlite.Row | db_postgres.Row | db_mysql.Row


template fromDb*(value: (string) -> any) {.pragma.}

template toDb*(value: (any) -> string) {.pragma.}

macro to*(row: Row, T: type): untyped =
  ##[Convert ``Row`` instance to an instance of type ``T``.

  ``T`` must be an object.

  .. code-block:: nim
    from db_sqlite import Row

    # Define an object type that reflects your business logic entity.
    type
      User = object
        name: string
        age: int
        height: float

    # Get a ``Row`` instance. It would normally come as a result of a DB query, but in this example we'll just define one.
    let row: Row = @["John", "42", "1.72"]

    # Create a ``User`` instance from the row.
    let user = row.to User

    # Note that field types from ``User`` are preserved even though all ``Row`` fields are strings.
    echo user
    # User(name: "John", age: 42, height: 1.72)
  ]##

  let typeNode = getTypeInst(T)[1]

  expectKind(typeNode.getType(), nnkObjectTy)

  let
    typeName = $typeNode
    typeImpl = getImpl(typeNode)
    recListNode = typeImpl[2][2]

  var toObjProc = newNimNode(nnkLambda).add(
    newEmptyNode(),
    newEmptyNode(),
    newNimNode(nnkGenericParams),
    newNimNode(nnkFormalParams).add(
      newIdentNode(typeName),
      newIdentDefs(
        newIdentNode("row"),
        newIdentNode("Row")
      )
    ),
    newEmptyNode(),
    newEmptyNode(),
    newStmtList(newNimNode(nnkDiscardStmt).add(newEmptyNode()))
  )

  for i, identDefsNode in recListNode:
    expectKind(identDefsNode[0], {nnkIdent, nnkPragmaExpr})

    let fieldName = case identDefsNode[0].kind
      of nnkIdent: $identDefsNode[0]
      of nnkPragmaExpr: $identDefsNode[0][0]
      else: raise newException(ValueError, "Unexpected node kind")

    let fieldType = getType(identDefsNode[1])

    var fromDbProc = case fieldType.typeKind
      of ntyInt: newIdentNode("parseInt")
      of ntyFloat: newIdentNode("parseFloat")
      else: newIdentNode("$")

    if identDefsNode[0].kind == nnkPragmaExpr:
      for pragmaDef in identDefsNode[0][1]:
        if pragmaDef.kind == nnkExprColonExpr and strVal(pragmaDef[0]) == "fromDb":
          fromDbProc = pragmaDef[1]
          break

    toObjProc.body.add newAssignment(
      newDotExpr(newIdentNode("result"), newIdentNode(fieldName)),
      newCall(
        fromDbProc,
        newNimNode(nnkBracketExpr).add(newIdentNode("row"), newLit(i))
      )
    )

    result = newCall(toObjProc, row)

template formatField(obj, field: NimIdent): untyped =
  when obj.field.hasCustomPragma(toDb):
    obj.field.getCustomPragmaVal(toDb)(obj.field)
  else:
    $obj.field

macro toRow*(obj: typed): untyped =
  ##[Convert from object instance to ``Row`` instance.

  .. code-block:: nim
    from db_sqlite import Row

    # Define an object type that reflects your business logic entity.
    type
      User = object
        name: string
        age: int
        height: float

    # Create a ``User`` instance.
    let user = User(name: "John", age: 42, height: 1.72)

    # Get a ``Row`` instance ready to be passed to a DB query.
    # let row = user.toRow()

    echo row
    # @["John", "42", "1.72"]
  ]##

  let objType = obj.getType()
  expectKind(objType, nnkObjectTy)

  let objTypeName = $obj.getTypeInst()

  var toRowProc = newNimNode(nnkLambda).add(
    newEmptyNode(),
    newEmptyNode(),
    newNimNode(nnkGenericParams),
    newNimNode(nnkFormalParams).add(
      newIdentNode("Row"),
      newIdentDefs(
        newIdentNode($obj),
        newIdentNode(objTypeName)
      )
    ),
    newEmptyNode(),
    newEmptyNode(),
    newStmtList(newNimNode(nnkDiscardStmt).add(newEmptyNode()))
  )

  for field in objType[2]:
    toRowProc.body.add newCall(
      newIdentNode("add"),
      newIdentNode("result"),
      getAst(formatField(ident($obj), ident($field)))
    )

  result = newCall(toRowProc, obj)
