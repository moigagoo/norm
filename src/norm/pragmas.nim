##[
  #######
  Pragmas
  #######

  Pragmas to customize the database representation of the object model.

]##

template pk* {.pragma.}
  ## Mark field as primary key. The special field ``id`` is mark with ``pk`` by default.

template ro* {.pragma.}
  ##[ Mark field as read-only.

  Read-only fields are ignored in ``insert`` and ``update`` unless ``force`` is passed.

  Use for fields that are populated automatically by the DB: ids, timestamps, and so on.
  The special field ``id`` is mark with ``pk`` by default.
  ]##

template fk*(val: typed) {.pragma.}
  ##[ Mark field as foreign key another type. ``val`` is either a type or a "type.field"
  expression. If a type is provided, its ``id`` field is referenced.
  ]##

template dbCol*(val: string) {.pragma.}
  ## DB native column name to use in table schema.

template dbType*(val: string) {.pragma.}
  ## DB native type to use in table schema.

template default*(val: string) {.
  pragma, deprecated: "Default values are set automatically, this is ignored.".}
  ## Default value for the DB column.

template notNull* {.
  pragma, deprecated: "NOT NULL is the default with all fields exception Options, this is ignored.".}
  ## Add ``NOT NULL`` constraint.

template check*(val: string) {.pragma.}
  ## Add a ``CHECK <CONDITION>`` constraint.

template unique* {.pragma.}
  ## Add a ``UNIQUE`` constraint.

template onDelete*(val: string) {.pragma.}
  ## Add an ``ON DELETE <POLICY>`` constraint.

template onUpdate*(val: string) {.pragma.}
  ## Add an ``ON UPDATE <POLICY>`` constraint.

template table*(val: string) {.pragma, deprecated: "`table` has been renamed to `dbTable`".}
  ## Set table name. Lowercased type name is used when unset.

template dbTable*(val: string) {.pragma.}
  ## Set table name. Lowercased type name is used when unset.
