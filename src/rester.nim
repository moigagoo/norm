import sugar
import db_sqlite

import rester / restorm


type
  User = object
    id: int
    email: string
    age: int


when isMainModule:
  let
    dbConn = open("rester.db", "", "", "")
    getAllUsers = () => User.getAll(dbConn, "users")
    getUserById = (id: int) => User.getById(dbConn, "users", id)

  echo '\n' & "All users: "
  for user in getAllUsers():
    echo '\t' & $user

  echo '\n' & "User with id=1: " & '\n' & '\t' & $getUserById(1)
