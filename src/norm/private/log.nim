import std/[logging, strutils]

type
  LoggingError* = object of CatchableError


proc log*(msg: string) {.raises: LoggingError.} =
  ## Log arbitrary message with debug level if the app is compiled with ``-d:normDebug``.

  when defined(normdebug):
    try:
      debug msg
    except:
      raise newException(LoggingError, getCurrentExceptionMsg())

proc log*(qry, paramstr: string) {.raises: {ValueError, LoggingError}.} =
  ## Log query with params with debug level if the app is compiled with ``-d:normDebug``.

  log "$# <- $#" % [qry, paramstr]

