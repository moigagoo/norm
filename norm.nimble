# Package

version       = "2.6.1"
author        = "Constantine Molchanov"
description   = "Nim ORM for SQLite and PostgreSQL."
license       = "MIT"
srcDir        = "src"
skipDirs      = @["tests", "htmldocs"]


# Dependencies

requires "nim >= 1.4.0", "ndb >= 0.19.9", "nimble >= 0.14.1"

taskRequires "book", "nimib >= 0.3.4", "nimibook#280a626a902745b378cc2186374f14c904c9a606"

task test, "Run tests":
  exec "testament all"

task book, "Generate book":
  rmDir "docs"
  exec "nim r -d:release nbook.nim update"
  exec "nim r -d:release nbook.nim build"
  cpFile("CNAME", "docs/CNAME")

task docs, "Generate docs":
  rmDir "docs/apidocs"
  exec "nimble doc --outdir:docs/apidocs --project --index:on src/norm"

