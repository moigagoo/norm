# Package

version       = "1.0.17"
author        = "Constantine Molchanov"
description   = "Nim ORM for SQLite and PostgreSQL."
license       = "MIT"
srcDir        = "src"


# Dependencies

requires "nim >= 1.0.0", "ndb#head"


# Tasks

import os

task docs, "Generate documentation":
  const
    docsDir = "docs"
    siteDir = "site"
    apiDocsPath = siteDir / "api"
    gitUrl = "https://github.com/moigagoo/norm/"
    defaultBranch = "develop"
    mainFilePath = "src" / "norm.nim"

  rmDir siteDir
  mkDir siteDir

  for file in listFiles(docsDir):
    if splitFile(file).ext == ".rst":
      let
        htmlFilename = changeFileExt(extractFilename(file), "html")
        htmlFilePath = siteDir / htmlFilename

      exec "nim rst2html -o:$# $#" % [htmlFilePath, file]

  exec "nim doc --project --index:on --git.url:$# --git.commit:$# -o:$# $#" % [
    gitUrl,
    defaultBranch,
    apiDocsPath,
    mainFilePath
  ]

  exec "nim buildIndex -o:$# $#" % [apiDocsPath/"theindex.html", apiDocsPath]
