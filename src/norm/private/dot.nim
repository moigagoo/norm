import std/macros


macro dot*(obj: ref object, fld: string): untyped =
  ## Turn ``obj.dot("fld")`` into ``obj.fld``.

  newDotExpr(obj, newIdentNode(fld.strVal))
