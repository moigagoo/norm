import nimib, nimibook

import tutorial/tables
import norm/[sqlite, model]
import std/[os, strutils]

nbInit(theme = useNimibook)


nbText: """
# Custom Datatypes

By default, Norm can deal with the following Nim types:
  - ``bool``
  - ``int/int8/16/32/64``
  - ``uint/uint8/16/32/64``
  - ``string``
  - ``DbBlob``
  - ``DateTime``
  - ``Model``

It does so by interacting with the database through a package called ``ndb``.
With ``ndb``, norm converts these nim types into the ``DbValue`` type which it then can convert to and from the various database-types.

More specifically, norm does this by specifying 3 procs. These procs specify which database-type to convert ``DbValue`` to,
 how to convert the nim type to ``DbValue`` and how to convert ``DbValue`` to the nim type.

If you want to have norm ``Models`` that contain your own custom types, you need to define these 3 procs for your nim type:
  - ``dbType(T: typedesc[YourType]) -> string`` - This maps your nim type to a database type (e.g. ``func dbType*(T: typedesc[string]): string = "TEXT"`` for sqlite)
  - ``dbValue(YourType) -> DbValue`` - This converts an instance of ``YourType`` to a ``DbValue`` instance.
  - ``to(DbValue, T: typedesc[YourType]) -> T`` - This converts a ``DbValue`` instance to an instance of ``YourType``.

Say for example we wanted to have an enum field on a model, that is stored as a string in our database:
"""

nbCode:
  # Required Code
  type CreatureFamily = enum
    BEAST = 1
    ANGEL = 2
    DEMON = 3
    HUMANOID = 4

  type Creature* = ref object of Model
      name*: string
      family*: CreatureFamily

  func dbType*(T: typedesc[CreatureFamily]): string = "TEXT"
  func dbValue*(val: CreatureFamily): DbValue = dbValue($val)
  proc to*(dbVal: DbValue, T: typedesc[CreatureFamily]): T = parseEnum[CreatureFamily](dbVal.s)

  # Example Usage
  putEnv("DB_HOST", ":memory:")
  let db = getDb()
  var human = Creature(name: "Karl", family: CreatureFamily.HUMANOID)

  db.createTables(human)
  db.insert(human)

  let rows = db.getAllRows(sql "SELECT name, family, id FROM creature")
  echo $rows # @[@['Karl', 'HUMANOID', 1]]

  var human2 = Creature()
  db.select(human2, "id = ?", human.id)

  assert human2.family == CreatureFamily.HUMANOID

nbText: """
Changing the above to store the enums as integers in your database is similarly easy.
All you'd need to do is change the 3 procs so that they store the enum in a different way.
"""

nbCode:
  type CreatureFamily2 = distinct CreatureFamily #Necessary to allow this book to compile

  func dbType*(T: typedesc[CreatureFamily2]): string = "INTEGER"
  func dbValue*(val: CreatureFamily2): DbValue = dbValue(val.int)
  proc to*(dbVal: DbValue, T: typedesc[CreatureFamily2]): CreatureFamily2 = dbVal.i.CreatureFamily2


nbSave
