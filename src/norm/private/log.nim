type
  LoggingError* = object of CatchableError


when defined(normDebug):
  import std/[logging, strutils]

  proc log*(msg: string) {.raises: LoggingError.} =
    ## Log arbitrary message with debug level if the app is compiled with ``-d:normDebug``.

    try:
      debug msg
    except:
      raise newException(LoggingError, getCurrentExceptionMsg())

  proc log*(qry, paramstr: string) {.raises: {ValueError, LoggingError}.} =
    ## Log query with params with debug level if the app is compiled with ``-d:normDebug``.

    log "$# <- $#" % [qry, paramstr]

else:
  proc log*(msg: string) = discard

  proc log*(qry, paramstr: string) = discard

