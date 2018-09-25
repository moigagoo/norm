import macros, db_sqlite


type
  User = object
    email: string
    age: int


template makeGetAll(idents: untyped, tableName: string): untyped =
  proc `getAll idents`(dbConn: DbConn): seq[Row] =
    dbConn.getAllRows sql"select * from ?", tableName

template makeGet(ident: untyped, tableName: string): untyped =
  proc `get ident`(dbConn: DbConn, id: int): Row =
    dbConn.getRow sql"select * from ? where rowid = ?", tableName, id

macro makeGetters*(ident, idents: untyped, tableName: string): untyped =
  result = newStmtList()
  result.add getAst makeGetAll(idents, tableName)
  result.add getAst makeGet(ident, tableName)


makeGetters(User, Users, "users")

let dbConn = open("rester.db", "", "", "")

echo dbConn.getAllUsers()
echo dbConn.getUser 1
