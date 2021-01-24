import unittest
import strutils

import norm/[model, postgres]

import ../models


const
  dbHost = "postgres"
  dbUser = "postgres"
  dbPassword = "postgres"
  dbDatabase = "postgres"


suite "Unique fields":
  proc resetDb =
    let dbConn = open(dbHost, dbUser, dbPassword, "template1")
    dbConn.exec(sql "DROP DATABASE IF EXISTS $#" % dbDatabase)
    dbConn.exec(sql "CREATE DATABASE $#" % dbDatabase)
    close dbConn

  setup:
    resetDb()
    let dbConn = open(dbHost, dbUser, dbPassword, dbDatabase)

    dbConn.createTables(newPerson())

  teardown:
    close dbConn
    resetDb()

  test "Insert duplicate values":
    var
      person1 = newPerson("Alice", "dadadadada","dada1", newPet("cat", newToy(123.45) ))
      person2 = newPerson("Alice", "dadadadadadadada", "dada2", newPet("dog", newToy(678.90)))

    dbConn.insert(person1)

    expect DbError:
      dbConn.insert(person2)


  test "Column Size":
    var 
      person3 = newPerson("Alice3", "dadadadaddadadaddaad", "dada3", newPet("dog", newToy(678.90)))
      person4 = newPerson("Alice4", "Person4", "dada04", newPet("dog", newToy(678.90)))
      person5 = newPerson("Alice5", "Person5", "dada5", newPet("dog", newToy(678.90)))


    expect DbError:
      dbConn.insert(person3)
    
    expect DbError:
      dbConn.insert(person4)
    
    dbConn.insert(person5)

