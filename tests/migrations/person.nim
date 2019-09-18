import options

import norm/sqlite


dbTypes:
  type
    Person1568833072* {.table: "person"} = object
      name*: string
      age*: int

    Person1569092269* {.table: "person"} = object
      name*: string
      age*: int
      ssn*: Option[int]
