## Pragmas to customize the database representation of the object model.

template pk* {.pragma.}
  ## Mark field as primary key. The special field ``id`` is mark with ``pk`` by default.

template ro* {.pragma.}
  ##[ Mark field as read-only.

  Read-only fields are ignored in ``insert`` and ``update`` unless ``force`` is passed.

  Use for fields that are populated automatically by the DB: ids, timestamps, and so on.
  The special field ``id`` is mark with ``pk`` by default.
  ]##

template dbCol*(val: string) {.pragma.}
  ## DB native column name to use in table schema. Field name is used when unset.

template dbType*(val: string) {.pragma.}
  ## DB native type to use in table schema.

template check*(val: string) {.pragma.}
  ## Add a ``CHECK <CONDITION>`` constraint.

template unique* {.pragma.}
  ## Add a ``UNIQUE`` constraint.

template onDelete*(val: string) {.pragma.}
  ## Add an ``ON DELETE <POLICY>`` constraint.

template onUpdate*(val: string) {.pragma.}
  ## Add an ``ON UPDATE <POLICY>`` constraint.

template dbTable*(val: string) {.pragma.}
  ## Set table name. Type name is used when unset.
