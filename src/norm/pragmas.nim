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
