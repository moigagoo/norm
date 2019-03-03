# Package

version       = "1.0.4"
author        = "Constantine Molchanov"
description   = "ORM that doesn't try to outsmart you."
license       = "MIT"
srcDir        = "src"


# Dependencies

requires "nim >= 0.19.4", "chronicles"


# Tasks

task docs, "Generate and upload API docs":
  exec "nim doc --project src/norm.nim"
  exec "ghp-import -np src/htmldocs"
