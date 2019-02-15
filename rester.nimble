# Package

version       = "0.1.0"
author        = "Konstantin Molchanov"
description   = "Utils to help create REST APIs with Jester."
license       = "MIT"
srcDir        = "src"
binDir        = "bin"
bin           = @["rester"]


# Dependencies

requires "nim >= 0.19.2", "chronicles"
