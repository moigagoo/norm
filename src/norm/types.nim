## Custom Nim types to give granular control over DB types.

import std/strutils


type
  StringOfCap*[C: static[int]] = distinct string
  PaddedStringOfCap*[C: static[int]] = distinct string


func newStringOfCap*[C: static[int]](val = ""): StringOfCap[C] =
  StringOfCap[C](val)

func newPaddedStringOfCap*[C: static[int]](val = ""): PaddedStringOfCap[C] =
  PaddedStringOfCap[C](val.alignLeft(C))

func `==`*[T](x, y: StringOfCap[T]): bool =
  string(x) == string(y)

func `==`*[T](x, y: PaddedStringOfCap[T]): bool =
  string(x) == string(y)

func `$`*[T](s: StringOfCap[T]): string =
  string(s)

func `$`*[T](s: PaddedStringOfCap[T]): string =
  string(s)

