# Package

version       = "2.8.6"
author        = "Constantine Molchanov"
description   = "Nim ORM for SQLite and PostgreSQL."
license       = "MIT"
srcDir        = "src"
skipDirs      = @["tests", "htmldocs"]


# Dependencies

requires "nim >= 1.4.0", "lowdb >= 0.2.1"

when NimMajor >= 2:
  taskRequires "setupBook", "nimib >= 0.3.8", "nimibook >= 0.3.1"
  taskRequires "benchmark", "benchy >= 0.0.1"
else:
  # Task Dependencies
  requires "nimib >= 0.3.8"
  requires "nimibook >= 0.3.1"
  requires "benchy >= 0.0.1"

# Tasks

task test, "Run tests":
  exec "testament all"

task setupBook, "Compiles the nimibook CLI-binary used for generating the docs":
  exec "nim c -d:release nbook.nim"

before book:
  rmDir "docs"
  exec "nimble setupBook"

task book, "Generate book":
  exec "./nbook --mm:orc --deepcopy:on update"
  exec "./nbook --mm:orc --deepcopy:on build"

after book:
  cpFile("CNAME", "docs/CNAME")

before docs:
  rmDir "docs/apidocs"

task docs, "Generate docs":
  exec "nimble doc --outdir:docs/apidocs --project --index:on src/norm"

task benchmark, "Run benchmark":
  exec "nim r benchmark/bulkUpdate.nim"


# For local development

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

