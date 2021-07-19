import std/strformat

import nimib, nimibook


nbInit
nbUseNimibook

nbText: """
# Manual Foreign Key Handling

Norm handles foreign keys automatically if you have a field of type `Model`. However, it has a downside: to fill up an object from the DB, Norm always fetches all related objects along with the original one, potentially generating a heavy JOIN query.

To work around that limitation, you can declare and handle foreign keys manually, with `fk` pragma:
"""

nbCode:
  import norm/[model, sqlite, pragmas]


  type
    Product = ref object of Model
      name: string
      price: float

    Consumer = ref object of Model
      email: string
      productId {.fk: Product.}: int64

  proc newProduct(): Product =
    Product(name: "", price: 0.0)

  proc newConsumer(email = "", productId = 0'i64): Consumer =
    Consumer(email: email, productId: productId)

nbText: """
When using `fk` pragma, foreign key must be handled manually, so `createTables` needs to be called for both `Model`s:
"""

nbCode:
  let db = open(":memory:", "", "", "")

  db.exec sql"PRAGMA foreign_keys = ON"

  db.createTables(newProduct())
  db.createTables(newConsumer())

nbText: """
Norm will generate the following table schema:

    CREATE TABLE IF NOT EXISTS "Product"(name TEXT NOT NULL, price FLOAT NOT NULL, id INTEGER NOT NULL PRIMARY KEY)
    CREATE TABLE IF NOT EXISTS "Consumer"(email TEXT NOT NULL, productId INTEGER NOT NULL, id INTEGER NOT NULL PRIMARY KEY, FOREIGN KEY (productId) REFERENCES "Product"(id))

`insert` statements can now be done using only `id`. This allows for more flexibility at the cost of more manual queries:
"""

nbCode:
  var cheese = Product(name: "Cheese", price: 13.30)
  db.insert(cheese)

  var bob = newConsumer("bob@mail.org", cheese.id)
  db.insert(bob)

nbText: &"""
On `insert`, Norm will generate the following queries :

    INSERT INTO "Product" (name, price) VALUES(?, ?) <- @['{cheese.name}', {cheese.price}]
    INSERT INTO "Consumer" (email, productId) VALUES(?, ?) <- @['{bob.email}', {bob.productId}]

If an invalid ID is passed, Norm will raise a `DbError` exception:
"""

nbCode:
  try:
    let badProductId = 133
    var paul = newConsumer("paul@mail.org", badProductId)
    db.insert(paul)

  except DbError:
    echo getCurrentExceptionMsg()

nbText: """
`select` queries will only return the `id` referenced and not the associated fields:
"""

nbCode:
  var consumer = newConsumer()
  db.select(consumer, "email = $1", "bob@mail.org")
  doAssert(consumer.email == "bob@mail.org")

  var product = newProduct()
  db.select(product, "id = $1", consumer.productId)
  doAssert(product.name == "Cheese")
  doAssert(product.price == 13.30)

nbText: &"""
Norm will generate the following query:

    SELECT "Consumer".email, "Consumer".productId, "Consumer".id FROM "Consumer"  WHERE email = $1 <- ['{consumer.email}']
    SELECT "Product".name, "Product".price, "Product".id FROM "Product"  WHERE id = $1 <- [{consumer.productId}]
"""

nbSave
