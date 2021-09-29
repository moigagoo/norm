import nimibook


var book = newBookFromToc("Norm: a Nim ORM", "book"):
  entry("Welcome to Norm!", "index.nim")
  entry("Models 101", "models.nim")
  section("Tutorial", "tutorial.nim"):
    entry("Tables", "tutorial/tables.nim")
    entry("Rows", "tutorial/rows.nim")
  entry("Fancy Syntax", "fancy.nim")
  entry("Transactions", "transactions.nim")
  entry("Configuration from Environment", "config.nim")
  entry("Manual Foreign Key Handling", "fk.nim")
  entry("Debugging SQL", "debug.nim")
  entry("Changelog", "changelog.nim")


book.git_repository_url = "https://github.com/moigagoo/norm"
book.favicon_escaped = """<link rel="icon" href="data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 100 100%22><text y=%22.9em%22 font-size=%2280%22>🦾</text></svg>">"""
book.preferred_dark_theme = "coal"

nimibookCli(book)
