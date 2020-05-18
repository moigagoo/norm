## Pragmas to customize ``norm.Model`` field representation in generated table schemas.


template pk* {.pragma.}
  ##[ Mark field as primary key.

  ``id`` field is ``pk`` by default.
  ]##

template ro* {.pragma.}
  ##[ Mark field as read-only.

  Read-only fields are ignored in ``insert`` and ``update`` unless ``force`` is passed.

  Use for fields that are populated automatically by the DB: ids, timestamps, and so on.

  ``id`` field is ``ro`` by default.
  ]##

template dbCol*(name: string) {.pragma.}
  ##[ Name of the column generated for a ``norm.Model`` field.

  If not set, the field name is used.
  ]##

template dbType*(val: string) {.pragma.}
  ##[ DB type to use in table schema for this field.

  If not set, matching type from ``norm.sqlite.dbtypes`` is used.
  ]##

template check*(cond: string) {.pragma.}
  ## Add ``CHECK <CONDITION>`` constraint.

template unique* {.pragma.}
  ## Add ``UNIQUE`` constraint.

template onDelete*(polc: string) {.pragma.}
  ## Add ``ON DELETE <POLICY>`` constraint.

template onUpdate*(polc: string) {.pragma.}
  ## Add ``ON UPDATE <POLICY>`` constraint.

template dbTable*(name: string) {.pragma.}
  ##[ Table name.

  If not set, the type name is used.
  ]##
