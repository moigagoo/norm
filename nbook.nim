import nimibook


var book = newBookFromToc("Norm: a Nim ORM", "book"):
  entry("Welcome to Norm!", "index.nim")
  section("Tutorial", "tutorial.nim"):
    entry("Tables", "tutorial/tables.nim")
    entry("Rows", "tutorial/rows.nim")
  entry("Fancy Syntax", "fancy.nim")
  entry("Transactions", "transactions.nim")

book.preferred_dark_theme = "coal"
book.git_repository_url = "https://github.com/moigagoo/norm"

nimibookCli(book)
