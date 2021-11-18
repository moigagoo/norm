import nimib, nimibook


nbInit
nbUseNimibook

nbText: """
# Models 101

A model is an abstraction for a unit of your app's business logic. For example, in an online shop, the models might be Product, Customer, and Discount. Sometimes, models are created for entities that are not visible for the end user, but that are necessary from the architecture point of view: User, CartItem, or Permission.

Models can relate to each each with one-to-one, one-to-many, many-to-many relations. For example, a CartItem can have many Discounts, whereas as a single Discount can be applied to many Products.

Models can also inherit from each other. For example, Customer may inherit from User.

In Norm, Models are ref objects inherited from `Model` root object:
"""

nbCode:
  import norm/model

  type
    BaseUser = ref object of Model
      email: string

nbText: """
From a model definition, Norm deduces SQL queries to create tables and insert, select, update, and delete rows. Norm converts Nim objects to rows, their fields to columns, and their types to SQL types and vice versa.

For example, for a model definition like the one above, Norm generates the following table schema:

    CREATE TABLE IF NOT EXISTS "User"(email TEXT NOT NULL, id INTEGER NOT NULL PRIMARY KEY)

Inherited models are just inherited objects:
"""

nbCode:
  type
    NamedUser = ref object of BaseUser
      name: string

nbText: """
To create relations between models, define fields subtyped from `Model`:
"""

nbCode:
  type
    User = ref object of Model
      email: string

    Customer = ref object of Model
      name: string
      user: User

nbText: """
To add a `UNIQUE` constraint to a field, use `{.unique.}` pragma.

`UNIQUE` constraint ensures all values in a column or a group of columns are distinct from one another.
"""

nbCode:
  import norm/pragmas

  type
    Client = ref object of Model
      email: string
      name {.unique.}: string

nbText: """
Norm will generate the following table schema:

    CREATE TABLE IF NOT EXISTS "User"(email TEXT NOT NULL, name TEXT NOT NULL UNIQUE, id INTEGER NOT NULL PRIMARY KEY)

## Custom Table Name

By default, a table is named after the model type, enclosed in double quotes, e.g. `User` model's table is called `"User"`.

To override this behavior and set a custom name for the generated table, use `tableName` pragma:
"""

nbCode:
  type
    Thing {.tableName: "ThingTable".} = ref object of Model
      attr: string

nbText """
This will result in this schema:

    CREATE TABLE IF NOT EXISTS "ThingTable"(attr TEXT NOT NULL, id INTEGER NOT NULL PRIMARY KEY)
"""

nbSave

