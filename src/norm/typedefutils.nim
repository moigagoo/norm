##[

##################################################
Procs to Inject ``id`` Field into Type Definitions
##################################################

In order for a type to be usable in DB schema generation, it must have ``id`` field marked with ``pk`` and ``ro`` pragmas.

This module contains procs to do that for a single type definition and entire type section.
]##

import macros

import objutils


proc ensureIdField(typeDef: NimNode): NimNode =
  ## Check if ``id`` field is in the object definition, insert it if it's not.

  result = newNimNode(nnkTypeDef)

  var objRepr = typeDef.toObjRepr()

  if "id" notin objRepr.fieldNames:
    let idField = FieldRepr(
      signature: SignatureRepr(
        name: "id",
        exported: true,
        pragmas: @[
          PragmaRepr(name: "pk", kind: pkFlag),
          PragmaRepr(name: "ro", kind: pkFlag)
        ]
      ),
      typ: ident "int"
    )
    objRepr.fields.insert(idField, 0)

  result = objRepr.toTypeDef()

proc ensureIdFields*(typeSection: NimNode): NimNode =
  ## Check if ``id`` field is in all object definitions in the given type section, insert it if it's not.

  result = newNimNode(nnkTypeSection)

  for typeDef in typeSection:
    result.add ensureIdField(typeDef)

proc ensureForeignKey*(typeDef: NimNode, types: seq[NimNode]): NimNode =
  ## Check if a foreign key is in the object definition, insert it if it's not.

  result = newNimNode(nnkTypeDef)

  var objRepr = typeDef.toObjRepr()

  # Loop through the fields. We're unable to directly modify the current `field`,
  # so we use an index variable and modify that instead.
  for index,field in pairs(objRepr.fields):
    if (field.typ in types) and not ("fk" in field.signature.pragmaNames):
      objRepr.fields[index].signature.pragmas.add(PragmaRepr(name: "fk", kind: pkKval, value: field.typ))
      objRepr.fields[index].signature.pragmas.add(PragmaRepr(name: "dbCol", kind: pkKval, value: newStrLitNode(field.signature.name & "Id")))
      objRepr.fields[index].signature.pragmas.add(PragmaRepr(name: "dbType", kind: pkKval, value: newStrLitNode("INTEGER NOT NULL")))

      # ` parseIt: TheModel.getOne(it.i.int)`
      objRepr.fields[index].signature.pragmas.add(PragmaRepr(name: "parseIt", kind: pkKval, value:
        newCall(
          newDotExpr(field.typ, newIdentNode("getOne")),
          newDotExpr(
            newDotExpr(newIdentNode("it"), newIdentNode("i")),
            newIdentNode("int")))))

      # `formatIt: ?it.id`
      objRepr.fields[index].signature.pragmas.add(PragmaRepr(name: "formatIt", kind: pkKval, value:
        prefix(
          newDotExpr(newIdentNode("it"), newIdentNode("id")),
          "?")))

  result = objRepr.toTypeDef()


proc ensureForeignKeys*(typeSection: NimNode): NimNode =
  ## Check if a foreign key is in all object definitions that require it, insert it if it's not.
  #return typeSection
  result = newNimNode(nnkTypeSection)

  # We can only detect models in the same typedef section, so add all the type
  # idents to a seq for easy access.
  var types = newSeq[NimNode]()
  for typedef in typeSection:
    types.add(typedef[0])

  for typeDef in typeSection:
    result.add ensureForeignKey(typeDef, types)
