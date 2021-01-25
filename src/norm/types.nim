## Custom Nim types to give more granular control over DB types.

import strutils


type
  StringOfCap*[C: static[int]] = distinct string
  PaddedStringOfCap*[C: static[int]] = distinct string


func newStringOfCap*[C: static[int]](val = ""): StringOfCap[C] =
  StringOfCap[C](val)

func newPaddedStringOfCap*[C: static[int]](val = ""): PaddedStringOfCap[C] =
  PaddedStringOfCap[C](val.alignLeft(C))

func `==`*[_](x, y: StringOfCap[_]): bool =
  string(x) == string(y)

func `==`*[_](x, y: PaddedStringOfCap[_]): bool =
  string(x) == string(y)

func `$`*[_](s: StringOfCap[_]): string =
  string(s)

func `$`*[_](s: PaddedStringOfCap[_]): string =
  string(s)
