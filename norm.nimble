# Package

version       = "2.2.0"
author        = "Constantine Molchanov"
description   = "Nim ORM for SQLite and PostgreSQL."
license       = "MIT"
srcDir        = "src"
skipDirs      = @["tests", "htmldocs"]


# Dependencies

requires "nim >= 1.4.0", "ndb >= 0.19.8"

task test, "Run tests":
  exec "testament all"

task docs, "Generate docs":
  rmDir "htmldocs"
  exec "nimble doc --outdir:htmldocs --project --index:on src/norm"
  exec "nim rst2html -o:htmldocs/index.html README.rst"
  exec "testament html"
  cpFile("testresults.html", "htmldocs/testresults.html")
  cpFile("CNAME", "htmldocs/CNAME")
