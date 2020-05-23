import norm/model


type
  Toy* = object of Model
    price*: float

  Pet* = object of Model
    species*: string
    favToy*: Toy

  Person* = object of Model
    name*: string
    pet*: Pet

func initToy*(price: float): Toy =
  Toy(price: price)

func initPet*(species: string, favToy: Toy): Pet =
  Pet(species: species, favToy: favToy)

func initPerson*(name: string, pet: Pet): Person =
  Person(name: name, pet: pet)

proc doublePrice*(toy: var Toy) =
  toy.price *= 2
