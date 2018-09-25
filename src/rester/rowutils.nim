## Macros to convert between objects and ``Row`` instances.

import macros

import strutils
export strutils

from db_sqlite import Row
from db_postgres import Row
from db_mysql import Row


type Row = db_sqlite.Row | db_postgres.Row | db_mysql.Row


macro to*(row: Row, T: typedesc): untyped =
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
  doAssert typeNode.typeKind == ntyObject

  let
    typeName = $typeNode
    typeImpl = getImpl(typeNode)
    recListNode = typeImpl[2][2]

  var toProc = newNimNode(nnkLambda).add(
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
    let
      fieldName = $identDefsNode[0]
      fieldType = getType(identDefsNode[1])
      fieldAssignmentNode = case fieldType.typeKind
        of ntyString:
          newAssignment(
            newDotExpr(newIdentNode("result"), newIdentNode(fieldName)),
            newNimNode(nnkBracketExpr).add(newIdentNode("row"), newLit(i))
          )
        of ntyInt:
          newAssignment(
            newDotExpr(newIdentNode("result"), newIdentNode(fieldName)),
            newCall(
              newIdentNode("parseInt"),
              newNimNode(nnkBracketExpr).add(newIdentNode("row"), newLit(i))
            )
          )
        of ntyFloat:
          newAssignment(
            newDotExpr(newIdentNode("result"), newIdentNode(fieldName)),
            newCall(
              newIdentNode("parseFloat"),
              newNimNode(nnkBracketExpr).add(newIdentNode("row"), newLit(i))
            )
          )
        else: newEmptyNode()

    toProc.body.add fieldAssignmentNode

    result = newCall(toProc, row)

macro toRow*(obj: untyped): untyped =
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
  doAssert objType.typeKind == ntyObject

  let objTypeName = $obj.getTypeInst()

  var fromRowProc = newNimNode(nnkLambda).add(
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
    fromRowProc.body.add newCall(
      newIdentNode("add"),
      newIdentNode("result"),
      newNimNode(nnkPrefix).add(
        newIdentNode("$"),
        newDotExpr(newIdentNode($obj), newIdentNode($field))
      )
    )

  result = newCall(fromRowProc, obj)
