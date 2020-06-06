import sequtils

import norm/model


type
  Toy* = ref object of Model
    price*: float

  Pet* = ref object of Model
    species*: string
    favToy*: Toy

  Person* = ref object of Model
    name*: string
    pet*: Pet

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

func newPerson*(name: string, pet: Pet): Person =
  Person(name: name, pet: pet)

func newPerson*(): Person = newPerson("", newPet())

func `===`*(a, b: Person): bool =
  a.name == b.name and
  a.pet === b.pet

func `===`*[T: Toy | Pet | Person](a, b: openArray[T]): bool =
  zip(a, b).allIt(it[0] === it[1])

proc doublePrice*(toy: var Toy) =
  toy.price *= 2
