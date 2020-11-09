import sequtils
import options
import times

import norm/[model, pragmas]


type
  Toy* = ref object of Model
    price*: float

  Pet* = ref object of Model
    species*: string
    favToy*: Toy

  Person* = ref object of Model
    name* {.unique.}: string
    pet*: Option[Pet]

  PetPerson* = ref object of Model
    pet*: Pet
    person*: Person

  User* = ref object of Model
    lastLogin*: DateTime

  Customer* = ref object of Model
    userId* {.fk: User.}: int
    email*: string

  PlayfulPet* = ref object of Model
    species*: string
    favToy*: Toy
    secondFavToy*: Toy


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

proc newCustomer*(userId: int, email: string): Customer =
  Customer(userId: userId, email: email)

proc newCustomer*(userId: int): Customer =
  newCustomer(userId, "")

proc newCustomer*(): Customer =
  newCustomer(newUser().id)

func `===`*(a, b: Customer): bool =
  a.userId == b.userId and
  a.email == b.email

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

func `===`*[T: Toy | Pet | Person | PetPerson | User | Customer](a, b: openArray[T]): bool =
  len(a) == len(b) and zip(a, b).allIt(it[0] === it[1])

