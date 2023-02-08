import nimibook


var book = initBookWithToc:
  entry("Welcome to norm!", "index.nim")
  entry("Models 101", "models.nim")
  section("Tutorial", "tutorial.nim"):
    entry("Tables", "tutorial/tables.nim")
    entry("Rows", "tutorial/rows.nim")
    entry("Raw SQL interactions", "tutorial/rawSelects.nim")
    entry("Row Caveats", "tutorial/rowCaveats.nim")
  entry("Transactions", "transactions.nim")
  entry("Indexes", "indexes.nim")
  entry("Configuration from Environment", "config.nim")
  entry("Connection Pool", "pool.nim")
  entry("Manual Foreign Key Handling", "fk.nim")
  entry("Custom Datatypes", "customDatatypes.nim")
  entry("Fancy Syntax", "fancy.nim")
  entry("Debugging SQL", "debug.nim")
  entry("Changelog", "changelog.nim")


nimibookCli(book)

