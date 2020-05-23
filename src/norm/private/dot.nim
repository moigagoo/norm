import macros


macro dot*(obj: object, fld: string): untyped =
  ## Turn ``obj.dot("fld")`` into ``obj.fld``.

  newDotExpr(obj, newIdentNode(fld.strVal))
