import nimib, nimibook


nbInit(theme = useNimibook)

nbText: """
# Caveats
There are some caveats when working with Norm that you need to consider and strategies to work around them.

## Managing Data for Many-to-Many Relationships
Support for Many-To-Many relationships has not yet been fully reached. You will have to set-up and manage the necessary "glue"-models yourself as if they were regular models.

## Fetching data for more complex Many-To-One/Many-To-Many relationships
If you have multiple Many-To-X relationships that you want to query at once, you will need to make separate queries for each relationship. To keep the data together, you can make a new object-type that acts as a container for all the various queries. In this case, we add a `Employee` to the mix. We still want the data of the Producer, but now on top of the data of all their `Product`s we also want all of their `Employee`s. You can do this in a total of 3 queries (2 if you combine this with the previous approach, though this might be harder to maintain): 
"""

nbCode: 
  import std/json
  import norm/[model, sqlite]

  type Producer = ref object of Model
      name: string

  proc newProducer(name = ""): Producer = Producer(name: name)
    
  type Product = ref object of Model
      name: string
      producedBy: Producer

  proc newProduct(name = "", producedBy = newProducer()): Product = 
    result = Product(name: name, producedBy: producedBy)

  let dbConn = open(":memory:", "", "", "")

  dbConn.createTables(newProducer())
  dbConn.createTables(newProduct())

  var alex = newProducer("Alex")
  dbConn.insert(alex)
  var firstClassSpaghetti = newProduct("The best spaghetti", alex)
  dbConn.insert(firstClassSpaghetti)

  type Employee = ref object of Model
      name: string
      employer: Producer
    
  proc newEmployee(name = "", employer = newProducer()): Employee =
    result = Employee(name: name, employer: employer)

  dbConn.createTables(newEmployee())
  var steff = newEmployee("Steff", alex)
  dbConn.insert(steff)

  type ProducerContainer = object
    producer: Producer
    products: seq[Product]
    employees: seq[Employee]

  var producer: Producer = newProducer()
  var products: seq[Product] = @[newProduct()]
  var employees: seq[Employee] = @[newEmployee()]
  
  dbConn.select(producer, "Producer.id = ?", alex.id)
  dbConn.select(products, "producedBy = ?", alex.id)
  dbConn.select(employees, "employer = ?", alex.id)

  let producerContainer = ProducerContainer(
    producer: producer, 
    products: products,
    employees: employees
  )

  echo %*producerContainer

nbSave
