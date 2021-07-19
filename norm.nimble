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

task docs, "Generate docs":
  rmDir "htmldocs"
  exec "nimble doc --outdir:htmldocs --project --index:on src/norm"
  exec "nim rst2html -o:htmldocs/index.html README.md"
  exec "testament html"
  mvFile("testresults.html", "htmldocs/testresults.html")
  cpFile("CNAME", "htmldocs/CNAME")

task book, "Build book":
  rmDir "docs"
  exec "nim r -d:release nbook.nim build"
  exec "testament html"
  mvFile("testresults.html", "docs/testresults.html")
  cpFile("CNAME", "docs/CNAME")
