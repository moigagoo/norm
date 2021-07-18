import std/options

import nimib, nimibook
import norm/sqlite

import tutorial/tables


nbInit
nbUseNimibook

nbText: """
# Fancy Syntax

To avoid creating intermediate containers here and there, use Nim's `dup` macro to create mutable objects on the fly:
"""

nbCode:
  import sugar

nbText: """
For example, here's how you insert ten rows without having to create ten stale objects:
"""

nbCode:
  for i in 1..10:
    discard newUser($i & "@example.com").dup:
      dbConn.insert

nbText: """
`dup` lets you call multiple procs, which gives a pleasant interface for row filter and bulk manipulation:
"""

nbCode:
  discard @[newUser()].dup:
    dbConn.select("email LIKE ?", "_@example.com")
    dbConn.delete

nbSave
