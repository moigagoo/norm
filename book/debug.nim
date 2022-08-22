import nimib, nimibook


nbInit(theme = useNimibook)

nbText: """
# Debugging SQL

To enable the logging of SQL queries, define `normDebug` either by compiling with `-d:normDebug`, or by adding `switch("define", "normDebug")` to config.nims.

Once `normDebug` is defined, add a logger on debug level (see https://nim-lang.org/docs/logging.html for more info):
"""

nbCode:
  import logging
  var consoleLog = newConsoleLogger()
  addHandler(consoleLog)

nbSave

