import std/[sequtils, options, times]

import norm/[model, pragmas, types]


type
  Toy* = ref object of Model
    price*: float

  Pet* = ref object of Model
    species*: string
    favToy*: Toy

  PetSpecies* {.readOnly, tableName: "Pet".} = ref object of Model
    species*: string

  Person* = ref object of Model
    name* {.unique.}: string
    pet* {.onDelete: "CASCADE".}: Option[Pet]

  PersonName* {.ro, tableName: "Person".} = ref object of Model
    name*: string

  PetPerson* = ref object of Model
    pet*: Pet
    person*: Person

  DoctorVisit* = ref object of Model
    patient*: Person
    doctor*: Doctor
    visitTime*: DateTime

  User* = ref object of Model
    lastLogin*: DateTime

  Customer* = ref object of Model
    userId* {.fk: User.}: int64
    email*: string

  PlayfulPet* = ref object of Model
    species*: string
    favToy*: Toy
    secondFavToy*: Toy

  UnplayfulPet* = ref object of Model
    species*: string
    favToyId* {.fk: Toy}: Option[int64]

  Doctor* = ref object of Model
    name*: string
    age*: DateTime

  Specialty* = ref object of Model
    name*: string

  DoctorSpecialties* = ref object of Model
    specialtyAcquiredDate*: DateTime
    doctor*: Doctor
    specialty*: Specialty

  DoctorSpecialtiesFKPragma* = ref object of Model
    doctor* {.fk: Doctor}: int64
    specialty* {.fk: Specialty}: int64    

  Number* = ref object of Model
    n*: int
    n16*: int16
    n32*: int32
    n64*: int64

  String* = ref object of Model
    s*: string
    sc10*: StringOfCap[10]
    psc5*: PaddedStringOfCap[5]

  Table* {.tableName: "FurnitureTable".} = ref object of Model
    legCount*: Positive

  SelfRef* = ref object of Model
    parent* {.fk: SelfRef.}: Option[int64]

  Account* = ref object of Model
    status* {.uniqueGroup.}: int 
    email* {.uniqueGroup.}: string
 
  Student* = ref object of Model 
    firstName* {.index: "idx_student_names".}: string
    lastName* {.index: "idx_student_names".}: string
    email* {.index: "idx_student_emails".}: string


func newToy*(price: float): Toy =
  Toy(price: price)

func newToy*(): Toy = newToy(0.0)

func `===`*(a, b: Toy): bool =
  a[] == b[]

func newPet*(species: string, favToy: Toy): Pet =
  Pet(species: species, favToy: favToy)

func newPet*(): Pet = newPet("", newToy())

func `===`*(a, b: Pet): bool =
  a.species == b.species and
  a.favToy === b.favToy

func `===`*(a, b: Option[Pet]): bool =
  (a.isNone and b.isNone) or
  (a.isSome and b.isSome and get(a).species == get(b).species and
  get(a).favToy === get(b).favToy)

func newPerson*(name: string, pet: Option[Pet]): Person =
  Person(name: name, pet: pet)

func newPerson*(name: string, pet: Pet): Person =
  Person(name: name, pet: some pet)

func newPerson*(): Person = newPerson("", newPet())

func `===`*(a, b: Person): bool =
  a.name == b.name and
  a.pet === b.pet

proc doublePrice*(toy: var Toy) =
  toy.price *= 2

func newPetPerson*(pet: Pet, person: Person): PetPerson =
  PetPerson(pet: pet, person: person)

func newPetPerson*(): PetPerson =
  newPetPerson(newPet(), newPerson())

func `===`*(a, b: PetPerson): bool =
  a.pet === b.pet and
  a.person === b.person

proc newUser*(): User = User(lastLogin: now())

func `===`*(a, b: User): bool =
  a.lastLogin == b.lastLogin

proc newCustomer*(userId: int64, email: string): Customer =
  Customer(userId: userId, email: email)

proc newCustomer*(userId: int64): Customer =
  newCustomer(userId, "")

proc newCustomer*(): Customer =
  newCustomer(newUser().id)

func `===`*(a, b: Customer): bool =
  a.userId == b.userId and
  a.email == b.email

func newUnplayfulPet*(species: string = "", favToyId: Option[int64] = none(int64)): UnplayfulPet =
  UnplayfulPet(species: species, favToyId: favToyId)

func `===`*(a, b: UnplayfulPet): bool = 
  a.species == b.species and
  a.favToyId == b.favToyId

func newPlayfulPet*(species: string, favToy, secondFavToy: Toy): PlayfulPet =
  PlayfulPet(species: species, favToy: favToy, secondFavToy: secondFavToy)

func newPlayfulPet*(): PlayfulPet = newPlayfulPet("", newToy(), newToy())

func `===`*(a, b: PlayfulPet): bool =
  a.species == b.species and
  a.favToy === b.favToy and
  a.secondFavToy === b.secondFavToy

func `===`*(a, b: Option[PlayfulPet]): bool =
  (a.isNone and b.isNone) or
  (a.isSome and b.isSome and
  get(a).species == get(b).species and
  get(a).favToy === get(b).favToy and
  get(a).secondFavToy === get(b).secondFavToy)


func newDoctor*(name: string = "", age: DateTime = now()): Doctor = Doctor(name: name, age: age)
func `===`* (a, b: Doctor): bool = 
  a.name == b.name and a.id == b.id

func newSpecialty*(name: string = ""): Specialty = Specialty(name: name)
func `===`* (a, b: Specialty): bool =
  a.name == b.name and a.id == b.id

func newDoctorSpecialties*(doctor: Doctor = newDoctor(), specialty: Specialty = newSpecialty(), specialtyAcquiredDate: DateTime = now()): DoctorSpecialties =
  DoctorSpecialties(doctor: doctor, specialty: specialty, specialtyAcquiredDate: specialtyAcquiredDate)

func `===`* (a,b: DoctorSpecialties): bool = 
  a.doctor === b.doctor and a.specialty === b.specialty and a.specialtyAcquiredDate == b.specialtyAcquiredDate

func newDoctorSpecialtiesFKPragma*(doctorId: int64, specialtyId: int64): DoctorSpecialtiesFKPragma = 
  DoctorSpecialtiesFKPragma(doctor: doctorId, specialty: specialtyId)
func `===`*(a, b: DoctorSpecialtiesFKPragma): bool = 
  a.doctor == b.doctor and a.specialty == b.specialty 

func newDoctorVisit*(patient: Person = newPerson(), doctor: Doctor = newDoctor(), visitTime: DateTime = now()): DoctorVisit =
  DoctorVisit(patient: patient, doctor: doctor, visitTime: visitTime)

func `===`*[T: Toy | Pet | Person | PetPerson | User | Customer | DoctorVisit](a, b: openArray[T]): bool =
  len(a) == len(b) and zip(a, b).allIt(it[0] === it[1])

func newNumber*(n: int, n16: int16, n32: int32, n64: int64): Number =
  Number(n: n, n16: n16, n32: n32, n64: n64)

func newNumber*: Number =
  newNumber(0, 0'i16, 0'i32, 0'i64)

func `===`*(a, b: Number): bool =
  a[] == b[]

func newString*(s: string, sc10: StringOfCap[10], psc5: PaddedStringOfCap[5]): String =
  String(s: s, sc10: sc10, psc5: psc5)

func newString*: String =
  newString("", StringOfCap[10]"", PaddedStringOfCap[5]"")

func `===`*(a, b: String): bool =
  a[] == b[]

func newTable*(legCount: Positive = 4): Table =
  Table(legCount: legCount)

func newPetSpecies*: PetSpecies = PetSpecies(species: "")

func newPersonName*: PersonName = PersonName(name: "")

func newSelfRef*(): SelfRef =
  SelfRef(parent: none(int64))

func newSelfRef*(parentid: int64): SelfRef =
  SelfRef(parent: some(parentid))

func newAccount*(status = 0, email = ""): Account =
  Account(status: status, email: email)

func newStudent*(firstName = "", lastName = "", email = ""): Student =
  Student(firstName: firstName, lastName: lastName, email: email)

