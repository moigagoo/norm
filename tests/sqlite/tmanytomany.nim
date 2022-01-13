import std/[unittest, os, sugar, options, with]

import norm/[sqlite]

import ../models


const dbFile = "test.db"


suite "Testing Fetching Many-To-Many interactions":
  setup:
    removeFile dbFile

    let dbConn = open(dbFile, "", "", "")

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
    removeFile dbFile

  test "When there is a many-to-many relationship, fetch its members":
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
     