import times

import norm/sqlite


dbTypes:
  type
    User* = object
      email*: string
      lastLogin*: DateTime
