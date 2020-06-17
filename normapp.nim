import logging; addHandler newConsoleLogger()
import options
import std/with

import norm/[model, sqlite]


type
  User = ref object of Model
    email: string

  Customer = ref object of Model
    name: Option[string]
    user: User


func newUser(email = ""): User =
  User(email: email)

func newCustomer(name = none string, user = newUser()): Customer =
  Customer(name: name, user: user)


let dbConn = open("normapp.db", "", "", "")

dbConn.createTables(newCustomer())

var
  user1 = newUser("foo@foo.foo")
  user2 = newUser("bar@bar.bar")
  alice = newCustomer(some "Alice", user1)
  bob = newCustomer(some "Bob", user1)
  sam = newCustomer(some "Sam", user2 )

  aliceAndBob = [alice, bob]

with dbConn:
  insert aliceAndBob

  insert user2
  insert sam

close dbConn
