## Procs to convert `Model <../../model.html#Model>`_ instances or ref object instances to ``ndb.postgres.Row`` instances and back.

import std/options

import ndb/postgres

import dbtypes
import ../dot
import ../utils
import ../../model
import ../../pragmas

when (NimMajor, NimMinor) <= (1, 6):
  import ../../pragmasutils
else:
  import std/macros

func isEmptyColumn*(row: Row, index: int): bool =
  ## Checks whether the column at a given index is empty
  row[index].kind == dvkNull

## This does the actual heavy lifting for parsing
proc fromRowPos[T: ref object](obj: var T, row: Row, pos: var Natural, skip: static bool = false) =
  ##[ Convert ``ndb.sqlite.Row`` instance into `ref object`_ instance, from a given position.

  This is a helper proc to convert to `ref object`_ instances that have fields of the same type.
  ]##

  for fld, dummyVal in T()[].fieldPairs:
    when isRefObject(typeof(dummyVal)):                 ## If we're dealing with a ``ref object`` field
      if dot(obj, fld).toOptional().isSome:             ## and it's either a ``some ref object`` or ``ref object``
        var subMod = dot(obj, fld).toOptional().get()   ## then we try to populate it with the next ``row`` values.

        if row.isEmptyColumn(pos):                      ## If we have a ``NULL`` at this point, we return an empty ``ref object``:
          when typeof(dummyVal) is Option:              ## ``val`` is guaranteed to be either ``ref object`` or an ``Option[ref object]`` at this point,
            when isRefObject(dummyVal):
              dot(obj, fld) = none typeof(subMod)       ## and the fact that we got a ``NULL`` tells us it's an ``Option[ref object]``,

          inc pos
          subMod.fromRowPos(row, pos, skip = true)      ## Then we skip all the ``row`` values that should've gone into this submodel.

        else:                                           ## If ``row[pos]`` is not a ``NULL``,
          inc pos                                       ##
          subMod.fromRowPos(row, pos)                   ## we actually populate the submodel.

      else:                                             ## If the field is a ``none ref object``,
        inc pos                                         ## don't bother trying to populate it at all.
                                          
    else:
      when not skip:                                    ## If we're dealing with an "ordinary" field,
        dot(obj, fld) = row[pos].to(typeof(dummyVal))   ## just convert it.
        inc pos

      else:
        inc pos
  

proc fromRow*[T: ref object](obj: var T, row: Row) =
  ##[ Populate `ref object`_ instance from ``ndb.postgres.Row`` instance.

  Nested `ref object`_ fields are populated from the same ``ndb.postgres.Row`` instance.
  ]##

  var pos: Natural = 0
  obj.fromRowPos(row, pos)

proc toRow*[T: Model](obj: T, force = false): Row =
  ##[ Convert `Model`_ instance into ``ndb.postgres.Row`` instance.

  If ``force`` is ``true``, fields with `ro <../../pragmas.html#ro.t>`_ pragma are not skipped.
  ]##

  for fld, val in obj[].fieldPairs:
    if force or not (obj.dot(fld).hasCustomPragma(ro) or obj.dot(fld).hasCustomPragma(readOnly)):
      result.add dbValue(val)

