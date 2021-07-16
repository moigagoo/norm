import nimibook


var book = newBookFromToc("Norm: a Nim ORM", "book"):
  entry("Welcome to Norm!", "index.nim")
  section("Tutorial", "tutorial.nim"):
    entry("Tables", "tutorial/tables.nim")
    entry("Rows", "tutorial/rows.nim")

nimibookCli(book)
