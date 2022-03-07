import std/macros


macro dot*(obj: typed, fld: string): untyped =
  ## Turn ``obj.dot("fld")`` into ``obj.fld``.

  newDotExpr(obj, newIdentNode(fld.strVal))


template hasField*(t: typed, fieldName: static string): bool =
  ## Checks if the given type `t` has a field with the name provided in `fieldName`
  compiles(dot(t, fieldName))