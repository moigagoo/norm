## ``dot`` macro that turns ``obj("fld")`` into ``obj.fld``.


import macros


macro dot*(obj: object, fld: string): untyped =
  newDotExpr(obj, newIdentNode(fld.strVal))
