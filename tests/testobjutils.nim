import unittest

import macros

import norm / objutils


suite "Getting and setting object fields using bracket notation":
  type
    Color = enum
      red, green

    Rectangle = object
      width, height: float
      color: Color

  setup:
    let
      width = 400.0
      height = 300.003
      color = red

    var rect = Rectangle(width: width, height: height, color: color)

  test "Get field values":
    check rect.dot("width") == width
    check rect.dot("height") == height
    check rect.dot("color") == color

  test "Set field values":
    let
      newWidth =300.0
      newHeight = 200.0
      newColor = green
      newRect = Rectangle(width: newWidth, height: newHeight, color: newColor)

    rect.dot("width") = newWidth
    rect.dot("height") = newHeight
    rect.dot("color") = newColor

    check rect == newRect
