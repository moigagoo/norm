import ndb/postgres {.all.}
import ndb/wrappers/libpq

proc execExpect(db: DbConn, query: SqlQuery, args: seq[DbValue],
                 expectedStatusType: ExecStatusType) =
  ## execute a statement with an expected status type
  proc pgResHandler(res: PPGresult): bool {.raises: [], tags: [].} = pqresultStatus(res) == expectedStatusType
  if not tryWithStmt(db, query, args, expectedStatusType, pgResHandler):
    dbError(db)

proc execExpectTuplesOk*(db: DbConn, query: SqlQuery, args: seq[DbValue]) =
  ## execute a statement with a PGRES_TUPLES_OK as expected type
  execExpect(db, query, args, PGRES_TUPLES_OK)

