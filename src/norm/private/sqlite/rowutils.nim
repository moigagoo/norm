## Procs to convert ``norm.Model`` instances to ``ndb.sqlite.Row`` instances and back.

import macros

import ndb/sqlite

import norm/private/dot
import norm/private/sqlite/dbtypes
import norm/[model, pragmas]


proc fromRowPos[T: Model](obj: var T, row: Row, pos: var Natural) =
  ##[ Convert ``ndb.sqlite.Row`` instance into ``norm.Model`` instance, from a given position.

  This is a helper proc to convert to ``norm.Model`` instances that have fields of the same type.
  ]##

  for fld, val in obj.fieldPairs:
    when val is Model:
      val.fromRowPos(row, pos)

    else:
      val = row[pos].to(typeof(val))
      inc pos

proc fromRow*[T: Model](obj: var T, row: Row) =
  ##[ Populate ``norm.Model`` instance from ``ndb.sqlite.Row`` instance.

  Nested ``norm.Model`` fields are populated from the same ``ndb.sqlite.Row`` instance.
  ]##

  var pos: Natural = 0
  obj.fromRowPos(row, pos)

proc toRow*[T: Model](obj: T, force = false): Row =
  ##[ Convert ``norm.Model`` instance into ``ndb.sqlite.Row`` instance.

  Fields with ``norm.pragmas.ro``pragma are skipped unless ``force`` is ``true``.
  ]##

  for fld, val in obj.fieldPairs:
    if force or not obj.dot(fld).hasCustomPragma(ro):
      result.add dbValue(val)
