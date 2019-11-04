import times

import norm/sqlite


dbTypes:
  type
    User* {.dbTable: "users".} = object
      email*: string
      lastLogin*: DateTime
