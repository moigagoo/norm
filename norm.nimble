# Package

version       = "1.1.3"
author        = "Constantine Molchanov"
description   = "Nim ORM for SQLite and PostgreSQL."
license       = "MIT"
srcDir        = "src"
skipDirs      = @["tests", "htmldocs"]


# Dependencies

requires "nim >= 1.0.0", "ndb >= 0.19.8"

task apidoc, "Generate API docs":
  --outdir:"htmldocs"
  --git.url: https://github.com/moigagoo/norm/
  --git.commit: develop
  --project
  --index:on

  setCommand "doc", "src/norm"

task idx, "Generate index":
  selfExec "buildIndex --out:htmldocs/theindex.html htmldocs"

task docs, "Generate docs":
  rmDir "htmldocs"
  exec "nimble apidoc"
  exec "nimble idx"
