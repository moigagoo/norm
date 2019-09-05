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
