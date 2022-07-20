## Pragmas to customize `Model <model.html#Model>`_ field representation in generated table schemas.


template pk* {.pragma.}
  ##[ Mark field as primary key.

  ``id`` field is ``pk`` by default.
  ]##

template ro* {.pragma.}
  ##[ Mark model or field as read-only.

  Read-only models can't be mutated, i.e. you can't call ``insert``, ``update``, or ``delete`` on their instances.

  Read-only fields are ignored in ``insert`` and ``update`` procs unless ``force`` is passed.

  Use for fields that are populated automatically by the DB: ids, timestamps, and so on.

  ``id`` field is ``ro`` by default.
  ]##

template readOnly* {.pragma.}
  ## Alias for `ro <pragmas.html#ro.t>`_ pragma.

template unique* {.pragma.}
  ## Mark field as unique.

template uniqueGroup* {.pragma.}
  ## Mark fields as a unique group. Add pragma to every field.

template fk*(val: typed) {.pragma.}
  ## Mark ``int`` field as foreign key. Foreign keys always references the field ``id`` of ``val``. ``val`` should be a Model.

template onDelete*(val: string) {.pragma.}
  ## Add ``ON DELETE {val}`` constraint to the column.

template tableName*(val: string) {.pragma.}
  ## Custom table name for a model.

