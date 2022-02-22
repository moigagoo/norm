import std/[unittest, os, sugar, options, with, strutils]

import norm/postgres

import ../models


const
  dbHost = "postgres"
  dbUser = "postgres"
  dbPassword = "postgres"
  dbDatabase = "postgres"

proc resetDb =
  let dbConn = open(dbHost, dbUser, dbPassword, "template1")
  dbConn.exec(sql "DROP DATABASE IF EXISTS $#" % dbDatabase)
  dbConn.exec(sql "CREATE DATABASE $#" % dbDatabase)
  close dbConn

suite "Testing selectOneToMany":
  setup:
    resetDb()
    let dbConn = open(dbHost, dbUser, dbPassword, dbDatabase)

    var
      alice = newPerson("Alice", none Pet)
      bob = newPerson("Bob", none Pet)
      jeff = newPerson("Jeff", none Pet)

      someDoctor = newDoctor("Vet1")

      visit1 = newDoctorVisit(alice, someDoctor)
      visit2 = newDoctorVisit(bob, someDoctor)

      boneToy = newToy()
      ballToy = newToy()

      spot = newPlayfulPet("spot", boneToy, ballToy)

    dbConn.createTables(newPerson())
    dbConn.createTables(newDoctor())
    dbConn.createTables(newDoctorVisit())
    dbConn.createTables(newToy())
    dbConn.createTables(newPlayfulPet())
    discard @[alice, bob, jeff].dup:
      dbConn.insert
    
    discard @[someDoctor].dup:
      dbConn.insert
    
    discard @[visit1, visit2].dup:
      dbConn.insert
      
    discard @[boneToy, ballToy].dup:
      dbConn.insert
      
    discard @[spot].dup:
      dbConn.insert
  
  teardown:
    close dbConn
    resetDb()

  test "When there is a many-to-one relationship between two models and the entry has related entries, fetch those related entries":
    var doctorVisits: seq[DoctorVisit] = @[newDoctorVisit()]

    dbConn.selectOneToMany(alice, doctorVisits)

    check doctorVisits.len() == 1
    check doctorVisits[0].doctor === someDoctor

  test "When there is multiple many-to-one relationships between two models and the type field for fetching the desired relationship is specified, then fetch the entries of that relationship":
    var doctorVisits: seq[DoctorVisit] = @[newDoctorVisit()]

    dbConn.selectOneToMany(alice, doctorVisits, "patient")

    check doctorVisits.len() == 1
    check doctorVisits[0].doctor === someDoctor

  
  test "When there is a many-to-one relationship between two models and the entry has no related entries, fetch an empty seq[]":
    var doctorVisits: seq[DoctorVisit] = @[newDoctorVisit()]

    dbConn.selectOneToMany(jeff, doctorVisits)

    check doctorVisits.len() == 0

  test "When there is multiple many-to-one relationships between two models and the type field for fetching the desired relationship is not specified, then do not compile":
    var dogsFavoringBallToy = @[newPlayfulPet()]
    check compiles(dbConn.selectOneToMany(ballToy, dogsFavoringBallToy)) == false

  test "When there is no many-to-one relationship between two models, do not compile":
    var alicesPets: seq[Pet] = @[newPet()]
    check compiles(dbConn.selectOneToMany(alice, alicesPets)) == false

  test "When there is a many-to-one relationships between two models and a field that does not point to the table of the related model is specified, then do not compile":
    var doctorVisits: seq[DoctorVisit] = @[newDoctorVisit()]

    check compiles(dbConn.selectOneToMany(alice, doctorVisits, "incorrectFieldName")) == false #Field name given that does not exist
    check compiles(dbConn.selectOneToMany(alice, doctorVisits, "")) == false #No field name given
    check compiles(dbConn.selectOneToMany(alice, doctorVisits, "visitTime")) == false #Valid field name given that contains neither a model type, nor has an fk pragma
    check compiles(dbConn.selectOneToMany(alice, doctorVisits, "doctor")) == false #Valid field name given that does not point a model with the table name "Person"


suite "Testing selectManyToMany":
  setup:
    resetDb()
    let dbConn = open(dbHost, dbUser, dbPassword, dbDatabase)

    var
      acula = newDoctor("acula")
      jordan = newDoctor("jordan")
      unspecialDoctor = newDoctor("I have no specialties")

      bloodlettingSpecialty = newSpecialty("bloodletting")
      surgerySpecialty = newSpecialty("surgery")
      hypnosisSpecialty = newSpecialty("hypnosis")

      aculaBloodletting = newDoctorSpecialties(acula, bloodlettingSpecialty)
      aculaSurgery = newDoctorSpecialties(acula, surgerySpecialty)
      aculaHypnosis = newDoctorSpecialties(acula, hypnosisSpecialty)
      jordanSurgery = newDoctorSpecialties(jordan, surgerySpecialty)

    dbConn.createTables(newDoctor())
    dbConn.createTables(newSpecialty())
    dbConn.createTables(newDoctorSpecialties())

    with dbConn:
      insert(acula)
      insert(jordan)
      insert(bloodlettingSpecialty)
      insert(surgerySpecialty)
      insert(hypnosisSpecialty)
      insert(aculaBloodletting)
      insert(aculaSurgery)
      insert(aculaHypnosis)
      insert(jordanSurgery)

  teardown:
    close dbConn
    resetDb()

  test "Given a many-to-many relationship, When the members linked to a specific entry are queried, Then return these members":
    var aculaSpecialties: seq[Specialty] = @[newSpecialty()]
    var doctorSpecialties: seq[DoctorSpecialties] = @[aculaBloodletting]
    
    dbConn.selectManyToMany(acula, doctorSpecialties, aculaSpecialties, "doctor", "specialty")

    check doctorSpecialties.len() == 3
    check aculaSpecialties.len() == 3
    check aculaSpecialties[0] === bloodlettingSpecialty
    check aculaSpecialties[1] === surgerySpecialty
    check aculaSpecialties[2] === hypnosisSpecialty

  test "Given a many-to-many relationship, When the members linked to a specific entry are queried with the fields that don't exist on the joinModel, then don't compile":
    var aculaSpecialties: seq[Specialty] = @[newSpecialty()]
    var doctorSpecialties: seq[DoctorSpecialties] = @[aculaBloodletting]
    
    check not compiles(dbConn.selectManyToMany(acula, doctorSpecialties, aculaSpecialties, "aNonexistantField", "specialty"))

  test "Given a many-to-many relationship, When the members linked to a specific entry are queried by passing fields that point to the wrong tables, then don't compile":
    var aculaSpecialties: seq[Specialty] = @[newSpecialty()]
    var doctorSpecialties: seq[DoctorSpecialties] = @[aculaBloodletting]
    
    check not compiles(dbConn.selectManyToMany(acula, doctorSpecialties, aculaSpecialties, "doctor", "doctor"))
    check not compiles(dbConn.selectManyToMany(acula, doctorSpecialties, aculaSpecialties, "specialty", "specialty"))
    check not compiles(dbConn.selectManyToMany(acula, doctorSpecialties, aculaSpecialties, "specialty", "doctor"))

  test "Given a many-to-many relationship, When the members linked to a specific entry are queried with a field that does not point to a model, Then don't compile":
    var aculaSpecialties: seq[Specialty] = @[newSpecialty()]
    var doctorSpecialties: seq[DoctorSpecialties] = @[aculaBloodletting]
    
    check not compiles(dbConn.selectManyToMany(acula, doctorSpecialties, aculaSpecialties, "specialtyAcquiredDate", "doctor"))
    check not compiles(dbConn.selectManyToMany(acula, doctorSpecialties, aculaSpecialties, "specialty", "specialtyAcquiredDate"))

  test "When there is a many-to-many relationship and the joinModel has only one FK-field to each model, fetch its members without specifying which fields to use":
    var aculaSpecialties: seq[Specialty] = @[newSpecialty()]
    var doctorSpecialties: seq[DoctorSpecialties] = @[aculaBloodletting]

    dbConn.selectManyToMany(acula, doctorSpecialties, aculaSpecialties)

    check doctorSpecialties.len() == 3
    check aculaSpecialties.len() == 3
    check aculaSpecialties[0] === bloodlettingSpecialty
    check aculaSpecialties[1] === surgerySpecialty
    check aculaSpecialties[2] === hypnosisSpecialty


 
  test "When there is a many-to-many relationship without any attached entries, fetch an empty seq[]":
    var specialtiesOfDoctor: seq[Specialty] = @[newSpecialty()]
    var specialtyRelationship: seq[DoctorSpecialties] = @[newDoctorSpecialties()]
    
    dbConn.selectManyToMany(unspecialDoctor, specialtyRelationship, specialtiesOfDoctor)

    check specialtiesOfDoctor.len() == 0
  

  test "When the join table has no field pointing to the starter model, the code does not compile":
    var specialtiesOfDoctor: seq[Specialty] = @[newSpecialty()]
    var specialtyRelationship: seq[DoctorSpecialties] = @[newDoctorSpecialties()]
    var aPet: Pet = newPet()
    check compiles(dbConn.selectManyToMany(aPet, specialtyRelationship, specialtiesOfDoctor)) == false

  test "When the join table has no field pointing to the end model, the code does not compile":
    var petSeq: seq[Pet] = @[newPet()]
    var specialtyRelationship: seq[DoctorSpecialties] = @[newDoctorSpecialties()]
    check compiles(dbConn.selectManyToMany(acula, specialtyRelationship, petSeq)) == false
     