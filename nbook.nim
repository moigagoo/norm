import nimibook


var book = initBookWithToc:
  entry("Welcome to Norm!", "index.nim")
  entry("Models 101", "models.nim")
  section("Tutorial", "tutorial.nim"):
    entry("Tables", "tutorial/tables.nim")
    entry("Rows", "tutorial/rows.nim")
    entry("Row Caveats", "tutorial/rowCaveats.nim")
  entry("Fancy Syntax", "fancy.nim")
  entry("Transactions", "transactions.nim")
  entry("Configuration from Environment", "config.nim")
  entry("Manual Foreign Key Handling", "fk.nim")
  entry("Debugging SQL", "debug.nim")
  entry("Changelog", "changelog.nim")


nimibookCli(book)

