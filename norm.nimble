# Package

version       = "1.0.17"
author        = "Constantine Molchanov"
description   = "Nim ORM for SQLite and PostgreSQL."
license       = "MIT"
srcDir        = "src"
skipDirs      = @["tests", "htmldocs"]


# Dependencies

requires "nim >= 1.0.0", "ndb >= 0.19.8"

task docs, "generate documentation":
  --docSeeSrcUrl: https://github.com/moigagoo/norm/blob/develop
  --project
  setCommand "doc", "src/norm"
