import times

import norm/sqlite


dbTypes:
  type
    User* {.table: "users".} = object
      email*: string
      lastLogin*: DateTime
