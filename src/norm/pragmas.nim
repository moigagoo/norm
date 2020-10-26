## Pragmas to customize `Model <model.html#Model>`_ field representation in generated table schemas.


template pk* {.pragma.}
  ##[ Mark field as primary key.

  ``id`` field is ``pk`` by default.
  ]##

template ro* {.pragma.}
  ##[ Mark field as read-only.

  Read-only fields are ignored in ``insert`` and ``update`` procs unless ``force`` is passed.

  Use for fields that are populated automatically by the DB: ids, timestamps, and so on.

  ``id`` field is ``ro`` by default.
  ]##

template unique* {.pragma.}
  ## Mark field as unique.

template fk*(val: typed) {.pragma.}
  ##[ Mark ``int`` field as foreign key. Foreign keys always references the field ``id`` of ``val``. ``val`` should be a Model.
  ]##
runnableExamples:
  import os
  import norm/model
  import norm/sqlite
  import norm/pragmas

  type
    Product = ref object of Model
      name : string
      price : float

    Consumer = ref object of Model
      name: string
      productId {.fk: Product.}: int

  proc newProduct(): Product=
    Product(name: "", price: 0.0)

  proc newConsumer(name: string = "", productId: int = 0): Consumer=
    Consumer(name: name, productId: productId)

  let dbName = getTempDir() / "example.db"
  # Clean db
  discard tryRemoveFile(dbName)
  let db = open(dbName, "", "", "")
  # Depending on how sqlite3 was compiled, enabling foreign_keys may be necessary
  db.exec(sql"PRAGMA foreign_keys = ON")

  block:
    db.createTables(newProduct())
    db.createTables(newConsumer())
    ##[Query Output:
    DEBUG CREATE TABLE IF NOT EXISTS "Product"(name TEXT NOT NULL, price FLOAT NOT NULL, id INTEGER NOT NULL PRIMARY KEY)
    DEBUG CREATE TABLE IF NOT EXISTS "Consumer"(name TEXT NOT NULL, productId INTEGER NOT NULL, id INTEGER NOT NULL PRIMARY KEY, FOREIGN KEY (productId) REFERENCES "Product"(id))
    ]##

  block:
    var cheese = Product(name:"Cheese", price: 13.30)
    db.insert(cheese)
    var bob = newConsumer("Bob", cheese.id)
    db.insert(bob)
    ##[Query Output:
    DEBUG INSERT INTO "Product" (name, price) VALUES(?, ?) <- @['Cheese', 13.3]
    DEBUG INSERT INTO "Consumer" (name, productId) VALUES(?, ?) <- @['Bob', 1]
    ]##

  block:
    let badProductId = 133
    var bob = newConsumer("Paul", badProductId)
    try:
      db.insert(bob)
    except DbError:
      discard
    ##[Query Output:
    Error: unhandled exception: FOREIGN KEY constraint failed [DbError]
    ]##


  block:
    var consumer = newConsumer()
    db.select(consumer, "name = $1", "Bob")
    doAssert(consumer.name == "Bob")
    var product = newProduct()
    db.select(product, "id = $1", consumer.productId)
    doAssert(product.name == "Cheese")
    doAssert(product.price == 13.30)
    ##[Query Output:
    DEBUG SELECT "Consumer".name, "Consumer".productId, "Consumer".id FROM "Consumer"  WHERE name = $1 <- ['Bob']
    DEBUG SELECT "Product".name, "Product".price, "Product".id FROM "Product"  WHERE id = $1 <- [1]
    ]##

  db.close()
  discard tryRemoveFile(dbName)
