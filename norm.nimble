# Package

version       = "2.1.5"
author        = "Constantine Molchanov"
description   = "Nim ORM for SQLite and PostgreSQL."
license       = "MIT"
srcDir        = "src"
skipDirs      = @["tests", "htmldocs"]


# Dependencies

requires "nim >= 1.2.0", "ndb >= 0.19.8"

task docs, "Generate docs":
  rmDir "htmldocs"
  exec "nimble doc --outdir:htmldocs --project --index:on src/norm"
  exec "nim rst2html -o:htmldocs/index.html README.rst"
  cpFile("CNAME", "htmldocs/CNAME")
