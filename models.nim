import logging
import norm / sqlite


db("petshop.db", "", "", ""):
  type
    User = object
      name: string
      age: int


when isMainModule:
  addHandler newConsoleLogger()

  withDb:
    createTables(force=true)

    var bob = User(name: "Bob", age: 23)
    bob.insert()

    bob.age = 34
    bob.update()

    bob.delete()
