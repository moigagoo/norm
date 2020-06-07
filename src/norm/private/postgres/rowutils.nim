## Procs to convert `Model <../../model.html#Model>`_ instances to ``ndb.postgres.Row`` instances and back.

import macros
import options

import ndb/postgres

import dbtypes
import ../dot
import ../../model
import ../../pragmas


proc fromRowPos[T: Model](obj: var T, row: Row, pos: var Natural) =
  ##[ Convert ``ndb.postgres.Row`` instance into `Model`_ instance, from a given position.

  This is a helper proc to convert to `Model`_ instances that have fields of the same type.
  ]##

  for fld, val in obj[].fieldPairs:
    if val.model.isSome:
      var subMod = get val.model
      subMod.fromRowPos(row, pos)

    else:
      val = row[pos].to(typeof(val))
      inc pos

proc fromRow*[T: Model](obj: var T, row: Row) =
  ##[ Populate `Model`_ instance from ``ndb.postgres.Row`` instance.

  Nested `Model`_ fields are populated from the same ``ndb.postgres.Row`` instance.
  ]##

  var pos: Natural = 0
  obj.fromRowPos(row, pos)

proc toRow*[T: Model](obj: T, force = false): Row =
  ##[ Convert `Model`_ instance into ``ndb.postgres.Row`` instance.

  If ``force`` is ``true``, fields with `ro <../../pragmas.html#ro.t>`_ pragma are not skipped.
  ]##

  for fld, val in obj[].fieldPairs:
    if force or not obj.dot(fld).hasCustomPragma(ro):
      result.add dbValue(val)
