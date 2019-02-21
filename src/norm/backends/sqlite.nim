import db_sqlite

import .. / .. / norm


proc genInsertQuery*(obj: object, force: bool): SqlQuery =
  ## Generate ``INSERT`` query for an object.

  var fields: seq[string]

  for field, _ in obj.fieldPairs:
    if force or not obj[field].hasCustomPragma(ro):
      fields.add field

  result = sql "INSERT INTO ? ($#) VALUES ($#)" % [fields.join(", "),
                                                    '?'.repeat(fields.len).join(", ")]

proc genGetOneQuery*(obj: object): SqlQuery =
  ## Generate ``SELECT`` query to fetch a single record for an object.

  sql "SELECT $# FROM ? WHERE id = ?" % obj.fieldNames.join(", ")

proc genGetManyQuery*(obj: object): SqlQuery =
  ## Generate ``SELECT`` query to fetch multiple records for an object.

  sql "SELECT $# FROM ? LIMIT ? OFFSET ?" % obj.fieldNames.join(", ")

proc getUpdateQuery*(obj: object, force: bool): SqlQuery =
  ## Generate ``UPDATE`` query for an object.

  var fieldsWithPlaceholders: seq[string]

  for field, value in obj.fieldPairs:
    if force or not obj[field].hasCustomPragma(ro):
      fieldsWithPlaceholders.add field & " = ?"

  result = sql "UPDATE ? SET $# WHERE id = ?" % fieldsWithPlaceholders.join(", ")

proc genDeleteQuery*(obj: object): SqlQuery =
  ## Generate ``DELETE`` query for an object.

  sql "DELETE FROM ? WHERE id = ?"
