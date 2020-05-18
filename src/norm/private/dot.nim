## ``dot`` macro that turns ``obj("fld")`` into ``obj.fld``.


import macros


macro dot*(obj: object, fieldName: string): untyped =
  newDotExpr(obj, newIdentNode(fieldName.strVal))
