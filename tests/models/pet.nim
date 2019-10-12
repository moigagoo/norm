import norm/sqlite

import user


dbTypes:
  type
    Pet* = object
      name*: string
      age*: int
      ownerId* {.fk: User, onDelete: "CASCADE".}: int
