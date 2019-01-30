import unittest

import rester / objutils


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
    check rect["width"] == width
    check rect["height"] == height
    check rect["color"] == color

  test "Set field values":
    let
      newWidth =300.0
      newHeight = 200.0
      newColor = green
      newRect = Rectangle(width: newWidth, height: newHeight, color: newColor)

    rect["width"] = newWidth
    rect["height"] = newHeight
    rect["color"] = newColor

    check rect == newRect
