import db_sqlite

import rowutils
export rowutils


proc getAll*(T: typedesc, dbConn: DbConn, tableName: string): seq[T] =
  for row in dbConn.fastRows(sql"SELECT rowid, * FROM ?", tableName):
    result.add row.to T

proc getById*(T: typedesc, dbConn: DbConn, tableName: string, id: int): T =
  dbConn.getRow(sql"SELECT rowid, * FROM ? WHERE rowid = ?", tableName, $id).to T
