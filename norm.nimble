# Package

version       = "2.3.0"
author        = "Constantine Molchanov"
description   = "Nim ORM for SQLite and PostgreSQL."
license       = "MIT"
srcDir        = "src"
skipDirs      = @["tests", "htmldocs"]


# Dependencies

requires "nim >= 1.4.0", "ndb >= 0.19.9", "nimibook >= 0.1.0"

task test, "Run tests":
  exec "testament all"

task book, "Generate book":
  exec "nim r -d:release nbook.nim build"
  cpFile("CNAME", "docs/CNAME")

task docs, "Generate docs":
  rmDir "docs/apidocs"
  exec "nimble doc --outdir:docs/apidocs --project --index:on src/norm"
