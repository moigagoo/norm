type
  LoggingError* = object of CatchableError


when defined(normDebug):
  import std/[logging, strutils]

  proc log*(msg: string) {.raises: {LoggingError, Exception}.} =
    ## Log arbitrary message with debug level if the app is compiled with ``-d:normDebug``.

    try:
      debug msg
    except CatchableError:
      raise newException(LoggingError, getCurrentExceptionMsg())

  proc log*(qry, paramstr: string) {.raises: {ValueError, LoggingError, Exception}.} =
    ## Log query with params with debug level if the app is compiled with ``-d:normDebug``.

    log "$# <- $#" % [qry, paramstr]

else:
  proc log*(msg: string) = discard

  proc log*(qry, paramstr: string) = discard

