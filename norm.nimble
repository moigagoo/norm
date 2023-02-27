# Package

version       = "2.6.2"
author        = "Constantine Molchanov"
description   = "Nim ORM for SQLite and PostgreSQL."
license       = "MIT"
srcDir        = "src"
skipDirs      = @["tests", "htmldocs"]


# Dependencies

requires "nim >= 1.4.0", "lowdb >= 0.1.1"


task test, "Run tests":
  exec "testament all"

task setupBook, "Compiles the nimibook CLI-binary used for generating the docs":
  exec "nimble install -y nimib nimibook@#280a626a902745b378cc2186374f14c904c9a606"
  exec "nim c -d:release --mm:refc nbook.nim"

task book, "Generate book":
  rmDir "docs"
  exec "nimble setupBook"
  exec "./nbook --mm:orc --deepcopy:on update"
  exec "./nbook --mm:orc --deepcopy:on build"
  cpFile("CNAME", "docs/CNAME")

task docs, "Generate docs":
  rmDir "docs/apidocs"
  exec "nimble doc --outdir:docs/apidocs --project --index:on src/norm"


## For Local Development

import std/[strutils, sequtils, strformat]

let postgresName = "norm-postgres-testcontainer"
putEnv("PGHOST", "localhost") ## Mandatory for all Postgres tests

proc asSudo(params: seq[string]): bool =
  return params.anyIt(it == "sudo")

task startContainers, "Starts a postgres container for running tests against":
  var command = fmt"""docker run -d -e POSTGRES_PASSWORD="postgres" --name {postgresName} --rm -p 5432:5432 postgres"""

  if commandLineParams.asSudo():
    command = fmt"sudo {command}"

  exec command

task stopContainers, "Stops a postgres container used for norm tests":
  var command = fmt"""docker stop {postgresName}"""

  if commandLineParams.asSudo():
    command = fmt"sudo {command}"

  exec command

task allTests, "Run all tests via testament":
  exec "testament all"

task singleTest, "Run containerized tests for a specific test file":
  let testFiles = commandLineParams.filterIt(it.startsWith("test"))

  for file in testFiles:
    let command = fmt"nimble c -r {file}"
    exec command