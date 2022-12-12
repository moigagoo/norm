import std/sugar
import std/logging

import nimib, nimibook
import norm/sqlite


addHandler newConsoleLogger(fmtStr = "")

nbInit(theme = useNimibook)

nbText: """
# Indexes

Index is a special table that makes use of data sortability to allow faster data access.

Indexes can be unique and not unique. The difference is the in a unique index, rows are guaranteed to be unique.

To create an index for you model, use `index` or `uniqueIndex` pragma passing the name of the index as its value:
"""

nbCode:
  import norm/[model, pragmas]

  type
    Person* = ref object of Model
      email* {.uniqueIndex: "Person_emails"}: string
      firstName* {.index: "Person_names".}: string
      lastName* {.index: "Person_names".}: string


nbText: """
With this type definition, we'll have two indexes, one unique, one non-unique.

The indexes are created together with the tables:
"""

nbCode:
  let dbConn* = open(":memory:", "", "", "")

  dbConn.createTables(Person())

  echo()

nbSave

