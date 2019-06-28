##[

###############
MongoDB Backend
###############

]##

#
# Interpreting between BSON and Nim Objects
#
# From BSON to Nim Types:
#
# | BSON          | Type      | Notes
# | ------------- | --------- | ---------------------
# | Double        | float     | default float in Nim already 64-bit
# | String (UTF8) | string    | string already UTF-8
# | Oid           | Oid       | https://nim-lang.org/docs/oids.html
# | Bool          | bool      | 
# | TimeUTC       | timestamp | https://nim-lang.org/docs/times.html
# | Null          | Option[T] | Only fields of Option[T] can be null
# | Int32         | int       | ideally, int32, but it will convert to int, int32, or int64
# | Int64         | int       | ideally, int64, bit it will convert to int, int32, or int64
#
# NOT YET SUPPORTED
#
# | Document      | (Object)  | field points to another object type. the other object need not be "dressed" with `db`
# | Array         | seq[T]    | we ONLY support same-type arrays right now
# Array (heterogeneous lists not supported yet)
# DBPointer
# Binary
# Timestamp
#
# NOT SUPPORTED (ignored):
#
# Regexp
# JSCode
# JSCodeWithScope
# MaximumKey
# MinimumKey
#
# From Nim Object to BSON
#
# | Type      | BSON          | Notes
# | --------- | ------------- |---------------------
# | float     | Double        | default float in Nim already 64-bit
# | string    | String (UTF8) | string already UTF-8
# | Oid       | Oid           | https://nim-lang.org/docs/oids.html; all-zeroes count as a MISSING entry; not a null
# | bool      | Bool          | 
# | timestamp | TimeUTC       | https://nim-lang.org/docs/times.html; 1970-01-01 00:00:00 counts as MISSING; not null
# | Option[T] | Null          | Only fields of Option[T] can be null
# | int       | Int32         |
#
# NOT YET SUPPORTED (compile-time error generated):
#
# | float32   | Double        | 
# | float64   | Double        | default float in Nim already 64-bit
# | (Object)  | Document      | it is not possible to a "Missing" state. The closest analogue is Option[ObjectType]
# | seq[T]    | Array         | to support null, make it seq[Option[T]]
# | int32     | Int32         |
# | int64     | Int64         |
# Tuples
# Tables
#

import
  strutils,
  macros,
  typetraits,
  logging,
  options,
  tables,
  oids,
  times

import
  nimongo.bson,
  nimongo.mongo

import
  rowutils,
  objutils,
  pragmas


export
  strutils,
  macros,
  logging,
  options,
  tables,
  oids,
  times

export
  bson,
  mongo

export
  rowutils,
  objutils,
  pragmas

const NORM_UNIVERSAL_TYPE_LIST* = @[
  "float",
  "string",
  "Oid",
  "bool",
  "Time",
  "int",
  "Option[float]",
  "Option[string]",
  "Option[Oid]",
  "Option[bool]",
  "Option[Time]",
  "Option[int]",
  "seq[float]",
  "seq[string]",
  "seq[Oid]",
  "seq[bool]",
  "seq[Time]",
  "seq[int]"
]

# proc `$`*(query: SqlQuery): string = $ string query

proc getCollectionName*(T: typedesc): string =
  ##[ Get the name of the DB table for the given type: ``table`` pragma value if it exists
  or lowercased type name otherwise.
  ]##

  when T.hasCustomPragma(table): T.getCustomPragmaVal(table)
  else: ($T).toLowerAscii()  



template genWithDb(connection, user, password, database: string): untyped {.dirty.} =
  ## Generate ``withDb`` templates.

  template withCustomDb*(customConnection, customUser, customPassword, customDatabase: string,
                         body: untyped): untyped {.dirty.} =
    ##[ A wrapper for actions that require custom DB connection, i.e. not the one defined in ``db``.
    Defines CRUD procs to work with the DB.

    'connection' should contain the URI pointing to the MongoDB server.

    The 'user' and 'password' parameters are not used.

    'database' should contain the database shard.

    Aforementioned procs and procs defined in a ``db`` block can be used only
    in  a ``withDb`` block.
    ]##

    block:
      var dbConn = newMongoWithURI(customConnection)
      let
        dbConnResult = dbConn.connect()

      # there is no 'dropTables'; that is a VERY non-mongo thing to do

      # there is no 'createTables'; that is a VERY non-mongo thing to do

      template insert(obj: var object, force = false) {.used.} =
        ##[ Insert object instance as a document into DB.The object's id is updated after
        the insertion.

        The ``force`` parameter is ignored by the mongodb library.
        ]##

        let
          doc = buildBSON(obj, true)
          dbCollection = dbConn[customDatabase][getCollectionName(type(obj))]

        # echo "collection: " & getCollectionName(type(obj))
        # echo "doc before:"
        # echo $doc

        var response = dbCollection.insert(doc)

        # echo "response: " & $response

        if len(response.inserted_ids) > 0:
          obj.id = response.inserted_ids[0].toOid

        # echo "doc after:"
        # echo $buildBSON(obj, true)
        # echo "object after:"
        # echo $obj

      template getOne(obj: var object, id: Oid) {.used.} =
        ## Read a record from DB by id and store it into an existing object instance.

        let
          dbCollection = dbConn[customDatabase][getCollectionName(type(obj))]

        let fetched = dbCollection.find(%*{"_id": id}).one()
        echo $fetched
        applyBSON(obj, fetched)

        # let getOneQuery = genGetOneQuery(obj, "id=?")

        # debug getOneQuery, " <- ", $id

        # let row = dbConn.getRow(getOneQuery, id)

        # if row.isNone():
        #   raise newException(KeyError, "Record with id=$# not found." % $id)

        # get(row).to(obj)



      try:
        # let foreignKeyQuery {.genSym.} = sql "PRAGMA foreign_keys = ON"
        # debug foreignKeyQuery
        # dbConn.exec foreignKeyQuery
        body
      finally: discard

#   template withDb*(body: untyped): untyped {.dirty.} =
#     ##[ A wrapper for actions that require DB connection. Defines CRUD procs to work with the DB,
#     as well as ``createTables`` and ``dropTables`` procs.

#       Aforementioned procs and procs defined in a ``db`` block can be used only
#       in  a ``withDb`` block.
#     ]##

#     withCustomDb(connection, user, password, database):
#       body


proc ensureIdFields(typeSection: NimNode): NimNode =
  ## Check if ``id`` field is in the object definition, insert it if it's not.

  result = newNimNode(nnkTypeSection)

  for typeDef in typeSection:
    var objRepr = typeDef.toObjRepr()

    if "id" notin objRepr.fieldNames:
      let idField = FieldRepr(
        signature: SignatureRepr(
          name: "id",
          exported: true,
          pragmas: @[
            PragmaRepr(name: "pk", kind: pkFlag),
            PragmaRepr(name: "ro", kind: pkFlag),
            PragmaRepr(name: "dbCol", kind: pkKval, value: parseExpr("\"_id\""))
          ]
        ),
        typ: ident "Oid"
      )
      objRepr.fields.insert(idField, 0)

    result.add objRepr.toTypeDef()

proc reconstructType(n: NimNode): string =
  if n.kind == nnkIdent:
    return $n
  if n.kind == nnkBracketExpr:
    return "$1[$2]".format($n[0], $n[1])
  return "unknown"

# # This proc generates a string conversion procedures in the form of:
# #
# # proc typedGet(t: type T, obj: Object, field: string): T =
# #   case field:
# #   of "fielda":
# #     return obj.fielda
# #   of "fieldb":
# #     return obj.fieldb
# #   else:
# #     discard
# #
# # where "T" is actually substituted for the type needing to be returned.
# # You can then use this like:
# #
# #    var x:int = typedGet(int, user, "age")
# #
# # As of nim 0.19.x, nim cannot do proc matching on the returned type
# #
# proc genObjectAccess(dbObjReprs: seq[ObjRepr]): string =
#   result = ""
#   var
#     proc_map = initOrderedTable[string, string]() # object__type name : procedure string
#     objectName = ""
#     typeName = ""
#     fieldName = ""
#     key = ""
#     normObjectNamesRegistry: seq[string] = @[]
#   #
#   # first get all of the object names
#   #
#   for obj in dbObjReprs:
#     objectName = obj.signature.name
#     normObjectNamesRegistry.add objectName
#   #
#   # create general procedure strings
#   #
#   for obj in dbObjReprs:
#     objectName = obj.signature.name
#     # create the other object reference procs
#     for typeName in normObjectNamesRegistry:
#       if objectName == typeName:
#         continue  # type recursion is forbidden by nim
#       key = objectName & "__" & typeName
#       proc_map[key] = ""
#       proc_map[key] &= "proc typedGet*(t: type $1, obj: $2, field: string): $1 {.used.} =\n".format(typeName, objectName)
#       proc_map[key] &= "  case field:\n"
#     # not apply the fields to those procs
#     for field in obj.fields:
#       # echo field.typ.treeRepr
#       typeName = reconstructType(field.typ)
#       fieldName = field.signature.name
#       key = objectName & "__" & typeName
#       if not proc_map.contains(key):
#         proc_map[key] = ""
#         proc_map[key] &= "proc typedGet*(t: type $1, obj: $2, field: string): $1 {.used.} =\n".format(typeName, objectName)
#         proc_map[key] &= "  case field:\n"
#       proc_map[key] &=   "  of \"$1\":\n".format(fieldName)
#       proc_map[key] &=   "    return obj.$1\n".format(fieldName)
#   #
#   # finish up all procedure strings
#   #
#   for key, s in proc_map.pairs():
#     proc_map[key] &= "  else:\n"
#     proc_map[key] &= "    discard\n"
#   # join up the procedures and return
#   for key, s in proc_map.pairs():
#     result &= s
#     result &= "\n" # add a blank line between each proc
#   #
#   # lastly, make the object names a globally accessable variable:
#   result &= "var normObjectNamesRegistry* = @[\n"
#   result &= "  \"" & join(normObjectNamesRegistry, "\", \"") & "\"\n"
#   result &= "]\n"

# this procedure generates new procedures the convert the values in an
# existing "type" object to a BSON object.
#
# So, for example, with object defined as:
#
# ```
# type
#   Pet* = object
#     shortName: string
#   User* = object
#     weight*: float
#     displayName*: string
#     thePet: Pet
# ```
# 
# you will get a string containing procedures similar to:
#
# ```
# proc buildBSON(obj: Pet, force = false): Bson =
#   result = newBsonDocument()
# 
#   result["shortName"] = toBson(obj.shortName)
# 
# proc buildBSON(obj: User, force = false): Bson =
#   result = newBsonDocument()
# 
#   if $obj.id != "000000000000000000000000":
#     result["_id"] = toBson(obj.id)
#   result["weight"] = toBson(obj.weight)
#   result["displayName"] = toBson(obj.displayName)
#   result["thePet"] = buildBSON(obj.thePet, force)
# 
# ```
proc genObjectToBSON(dbObjReprs: seq[ObjRepr]): string =
  var
    proc_map = initOrderedTable[string, string]() # object: procedure string
    objectName = ""
    typeName = ""
    fieldName = ""
    key = ""
    normObjectNamesRegistry: seq[string] = @[]

  #
  # first get all of the object names
  #
  for obj in dbObjReprs:
    normObjectNamesRegistry.add obj.signature.name
  #
  # now generate one buildBSON per object
  #
  for obj in dbObjReprs:
    objectName = obj.signature.name
    key = objectName
    proc_map[key] =  "proc buildBSON(obj: $1, force = false): Bson =\n".format(objectName)
    proc_map[key] &= "  result = newBsonDocument()\n"
    proc_map[key] &= "\n"
    #
    # handle universal types first
    #
    for field in obj.fields:
      typeName = reconstructType(field.typ)
      fieldName = field.signature.name
      if not NORM_UNIVERSAL_TYPE_LIST.contains(typeName):
        continue
      if typeName == "Oid":
        proc_map[key] &= "  if $$obj.$1 != \"000000000000000000000000\":\n".format(fieldName)
        proc_map[key] &= "    result[\"$1\"] = toBson(obj.$1)\n".format(fieldName)
      elif typeName == "Time":
        proc_map[key] &= "  if obj.$1 != fromUnix(0):\n".format(fieldName)
        proc_map[key] &= "    result[\"$1\"] = toBson(obj.$1)\n".format(fieldName)
      elif typeName.startsWith("Option["):
        proc_map[key] &= "  if obj.$1.isNone:\n".format(fieldName)
        proc_map[key] &= "    result[\"$1\"] = null()\n".format(fieldName)
        proc_map[key] &= "  else:\n"
        proc_map[key] &= "    result[\"$1\"] = toBson(obj.$1.get())\n".format(fieldName)
      elif typeName.startsWith("seq["):
        proc_map[key] &= "  result[\"$1\"] = newBsonArray()\n".format(fieldName)
        proc_map[key] &= "  for entry in obj.$1:\n".format(fieldName)
        proc_map[key] &= "    result[\"$1\"].add toBson(entry)\n".format(fieldName)
      else:
        proc_map[key] &= "  result[\"$1\"] = toBson(obj.$1)\n".format(fieldName)
    #
    # now handle cross-object references
    #
    for field in obj.fields:
      typeName = reconstructType(field.typ)
      fieldName = field.signature.name
      if NORM_UNIVERSAL_TYPE_LIST.contains(typeName):
        continue
      if normObjectNamesRegistry.contains(typeName):
        proc_map[key] &= "  result[\"$1\"] = buildBSON(obj.$1, force)\n".format(fieldName)
  #
  # finish up all procedure strings
  #
  for key, s in proc_map.pairs():
    result &= s
    result &= "\n" # add a blank line between each proc

const TYPE_TO_BSON_KIND = {
  "float": "BsonKindDouble",
  "string": "BsonKindStringUTF8",
  "Oid": "BsonKindOid",
  "bool": "BsonKindBool",
  "Time": "BsonKindTimeUTC",
  "int": "BsonKindInt64, BsonKindInt32"
}.toTable

const TYPE_TO_BSON_PROC = {
  "float": "toFloat64",
  "string": "toString",
  "Oid": "toOid",
  "bool": "toBool",
  "Time": "toTime",
  "int": "toInt"
}.toTable

# this procedure generates new procedures that map values found in an
# existing "type" object to a BSON object.
#
# So, for example, with object defined as:
#
# ```
# type
#   Pet* = object
#     shortName: string
#   User* = object
#     weight*: float
#     displayName*: string
#     thePet: Pet
# ```
# 
# you will get a string containing procedures similar to:
#
# ```
# proc applyBSON(obj: var Pet, doc: Bson) =
#   if doc.contains("shortName"):
#     if doc["shortName"].kind in @[BsonKindStringUTF8]:
#       obj.shortName = doc["shortName"].toString
# 
# proc applyBSON(obj: var User, doc: Bson) =
#   if doc.contains("_id"):
#     if doc["_id"].kind in @[BsonKindOid]:
#       obj.id = doc["_id"].toOid
#   if doc.contains("weight"):
#     if doc["weight"].kind in @[BsonKindDouble]:
#       obj.weight = doc["weight"].toFloat64
#   if doc.contains("displaName"):
#     if doc["displayName"].kind in @[BsonKindStringUTF8]:
#       obj.display_name = doc["displayName"].toString
#   if doc.contains("thePet"):
#     obj.thePet = Pet()
#     applyBSON(obj.my_pet, doc["thePet"])
# 
# ```
proc genBSONToObject(dbObjReprs: seq[ObjRepr]): string =
  var
    proc_map = initOrderedTable[string, string]() # object: procedure string
    objectName = ""
    typeName = ""
    fieldName = ""
    key = ""
    normObjectNamesRegistry: seq[string] = @[]
    center = ""

  #
  # first get all of the object names
  #
  for obj in dbObjReprs:
    normObjectNamesRegistry.add obj.signature.name
  #
  # now generate one applyBSON per object
  #
  for obj in dbObjReprs:
    objectName = obj.signature.name
    key = objectName
    proc_map[key] =  "proc applyBSON(obj: var $1, doc: Bson) =\n".format(objectName)
    #
    # handle universal types first
    #
    for field in obj.fields:
      typeName = reconstructType(field.typ)
      fieldName = field.signature.name
      if not NORM_UNIVERSAL_TYPE_LIST.contains(typeName):
        continue
      if typeName in ["float", "string", "Oid", "bool", "Time"]:
        proc_map[key] &= "  if doc.contains(\"$1\"):\n".format(fieldName)
        proc_map[key] &= "    if doc[\"$1\"].kind in @[$2]:\n".format(fieldName, TYPE_TO_BSON_KIND[typeName])
        proc_map[key] &= "      obj.$1 = doc[\"$1\"].$2\n".format(fieldName, TYPE_TO_BSON_PROC[typeName])
      elif typeName.startsWith("Option["):
        center = typeName.replace("Option[", "").replace("]", "")
        echo $center
        proc_map[key] &= "  if doc.contains(\"$1\"):\n".format(fieldName)
        proc_map[key] &= "    if doc[\"$1\"].kind in @[$2]:\n".format(fieldName, TYPE_TO_BSON_KIND[center])
        proc_map[key] &= "      obj.$1 = some doc[\"$1\"].$2\n".format(fieldName, TYPE_TO_BSON_PROC[center])
        proc_map[key] &= "    if doc[\"$1\"].kind == BsonKindNull:\n".format(fieldName)
        proc_map[key] &= "      obj.$1 = none($2)\n".format(fieldName, center)
      elif typeName.startsWith("seq["):
        center = typeName.replace("seq[", "").replace("]", "")
        echo $center
        proc_map[key] &= "  if doc.contains(\"$1\"):\n".format(fieldName)
        proc_map[key] &= "    obj.$1 = @[]\n".format(fieldName)
        proc_map[key] &= "    for item in doc[\"$1\"].items:\n".format(fieldName)
        proc_map[key] &= "      if item.kind in @[$1]:\n".format(TYPE_TO_BSON_KIND[center])
        proc_map[key] &= "        obj.$1.add item.$2\n".format(fieldName, TYPE_TO_BSON_PROC[center])
      else:
        discard
    #
    # now handle cross-object references
    #
    for field in obj.fields:
      typeName = reconstructType(field.typ)
      fieldName = field.signature.name
      if NORM_UNIVERSAL_TYPE_LIST.contains(typeName):
        continue
      if normObjectNamesRegistry.contains(typeName):
        proc_map[key] &= "  if doc.contains(\"$1\"):\n".format(fieldName)
        proc_map[key] &= "    obj.$1 = $2()\n".format(fieldName, typeName)
        proc_map[key] &= "    applyBSON(obj.$1, doc[\"$1\"])".format(fieldName)
  #
  # finish up all procedure strings
  #
  for key, s in proc_map.pairs():
    result &= s
    result &= "\n" # add a blank line between each proc


macro db*(connection, user, password, database: string, body: untyped): untyped =
  ##[ DB models definition. Models are defined as regular Nim objects in regular ``type`` sections.

  ``connection``, ``user``, ``password``, ``database`` are the same args accepted by a standard ``dbConn`` instance.

  The macro generates ``withDb`` template that wraps all DB interations.
  ]##

  result = newStmtList()

  var dbObjReprs: seq[ObjRepr]

  for node in body:
    if node.kind == nnkTypeSection:
      let typeSection = node.ensureIdFields()
      result.add typeSection

      for typeDef in typeSection:
        dbObjReprs.add typeDef.toObjRepr()

    else:
      result.add node

  # echo $dbObjReprs
  # echo $genObjectAccess(dbObjReprs)
  echo $genObjectToBSON(dbObjReprs)
  echo $genBSONToObject(dbObjReprs)


  # let objectAccess =  parseStmt(genObjectAccess(dbObjReprs))
  # result.add(objectAccess)

  let bsonToObject = parseStmt(genBSONToObject(dbObjReprs))
  result.add(bsonToObject)

  let objectToBSON = parseStmt(genObjectToBSON(dbObjReprs))
  result.add(objectToBSON)

  let withDbNode = getAst genWithDb(connection, user, password, database)
  result.insert(0, withDbNode)
