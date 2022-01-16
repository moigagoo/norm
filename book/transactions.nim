import std/sugar

import nimib, nimibook
import norm/sqlite

import tutorial/tables


nbInit
nbUseNimibook

nbText: """
# Transactions

To run queries in a transaction, wrap the code in a `transaction` block:
"""

nbCode:
  dbConn.transaction:
    for i in 11..13:
      discard newUser($i & "@example.com").dup:
        dbConn.insert

  echo()

nbText: """
If something goes wrong inside a transaction block, i.e. an exception is raised, the transaction is rollbacked.

To rollback a transaction manually, call `rollback` proc:
"""

nbCode:
  try:
    dbConn.transaction:
      for i in 14..16:
        discard newUser($i & "@example.com").dup:
         dbConn.insert

        if i == 15:
          rollback()

  except RollbackError:
    echo getCurrentExceptionMsg()

nbSave

