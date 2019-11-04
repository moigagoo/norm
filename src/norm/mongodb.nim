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
  sequtils,
  macros,
  typetraits,
  logging,
  options,
  tables,
  oids,
  times,
  asyncdispatch,
  algorithm # <- only used at compile-time, no need to export

import
  mongopool,
  bson

import
  rowutils,
  objutils,
  pragmas


export
  strutils,
  sequtils,
  macros,
  logging,
  options,
  tables,
  oids,
  times,
  asyncdispatch

export
  bson,
  mongopool

export
  rowutils,
  objutils,
  pragmas

# compile-time globals
var
  normObjectNamesRegistry {.compileTime.}: seq[string] = @[]
  varCounter {.compileTime.}: int = 1
  normBasicTypeList {.compileTime.} = @[
    "float",
    "string",
    "Oid",
    "bool",
    "Time",
    "int"
  ]
  normTypeToBsonKind {.compileTime.} = {
    "float": "BsonKindDouble",
    "string": "BsonKindStringUTF8",
    "Oid": "BsonKindOid",
    "bool": "BsonKindBool",
    "Time": "BsonKindTimeUTC",
    "int": "BsonKindInt64, BsonKindInt32"
  }.toTable
  normTypeToBsonProc {.compileTime.} = {
    "float": "toFloat64",
    "string": "toString",
    "Oid": "toOid",
    "bool": "toBool",
    "Time": "toTime",
    "int": "toInt"
  }.toTable

proc getCollectionName*(objRepr: ObjRepr): string =
  ##[ Get the name of the DB table for the given object representation:
  ``table`` pragma value if it exists or lowercased type name otherwise.
  ]##

  result = objRepr.signature.name.toLowerAscii()

  for prag in objRepr.signature.pragmas:
    if prag.name == "table" and prag.kind == pkKval:
      return $prag.value

proc getTableName*(objRepr: ObjRepr): string =
  getCollectionName(objRepr)

proc getCollectionName*(T: typedesc): string =
  ##[ Get the name of the DB table for the given type: ``table`` pragma value if it exists
  or lowercased type name otherwise.
  ]##

  when T.hasCustomPragma(table): T.getCustomPragmaVal(table)
  else: ($T).toLowerAscii()  

proc getTableName*(T: typedesc): string =
  getCollectionName(T)

var
  allCollections*: seq[string] = @[]

template addObjectsToCollection(newCollections: seq[string]): untyped {.dirty.} =
  ## simply add to global allCollections

  allCollections.insert(newCollections)

proc nextVar(prefix: string): string =
  ## get a new variable name
  result = prefix & $varCounter
  varCounter += 1

template genWithDb(newCollections: seq[string]): untyped {.dirty.} =
  ## Generate ``withDb`` templates.
  ##
  ## the connection, user, password, and database parameters have no meaning
  ## for the MongoDB mongopool library as the connections are pulled
  ## from a global thread pool that must already be established.

  allCollections.insert(newCollections)

  template withDb*(body: untyped): untyped {.dirty.} =
    ##[
    Defines CRUD procs to work with the DB.

    Aforementioned procs and procs defined in a ``db`` block can be used only
    in a ``withDb`` block.
    ]##

    var normDb = getNextConnection()

    block:

      template dropTables() {.used.} =
        ## Drops the collections for ALL objects.

        for collectionName in allCollections:
          discard ## TODO: make this work

      template createTables(force = false) {.used.} =
        ##[ For other database types, this function create new tables. However,
        for MongoDB this has less meaning since collections are auto-created.
        However, if `force` is set to true, it will dropTables first, deleting all
        the documents.
        ]##

        if force:
          dropTables()

      proc insert(obj: var object, force = false) {.used.} =
        ##[ Insert object instance as a document into DB. The object's id is
        updated after the insertion.

        The ``force`` parameter is ignored by the mongodb library.
        ]##

        let
          doc = toBson(obj, force)
          collectionName = getCollectionName(type(obj))
          returnedDoc = normDb.insertOne(collectionName, doc)
        obj.id = returnedDoc["_id"]

      proc getOne(obj: var object, id: Oid) {.used.} =
        ## Read a record from DB by id and apply it to an existing object instance.

        let
          collectionName = getCollectionName(type(obj))

        # let fetched = waitFor(dbCollection.find(@@{"_id": id}).one())
        let fetched = normDb.find(collectionName, @@{"_id": id}).returnOne()
        applyBson(obj, fetched)

      proc getOne(obj: var object, cond: Bson) {.used.} =
        ## Read a record from DB by search condition and apply it into an existing object instance.

        let
          collectionName = getCollectionName(type(obj))

        # let fetched = waitFor(dbCollection.find(cond).one())
        let fetched = normDb.find(collectionName, cond).returnOne()

        applyBson(obj, fetched)

      proc getOne(T: typedesc, id: Oid): T {.used.} =
        ## Read a record from DB by id and return a new object

        let
          collectionName = getCollectionName(T)

        # let fetched = waitFor(dbCollection.find(@@{"_id": id}).one())
        let fetched = normDb.find(collectionName, @@{"_id": id}).returnOne()

        applyBson(result, fetched)

      proc getOne(T: typedesc, cond: Bson): T {.used.} =
        ## Read a record from DB by search condition and return a new object

        let
          collectionName = getCollectionName(T)

        # let fetched = waitFor(dbCollection.find(cond).one())
        let fetched = normDb.find(collectionName, cond).returnOne()

        applyBson(result, fetched)

      proc getOneOption(T: typedesc, id: Oid): Option[T] {.used.} =
        ## Read a record from DB by id and return a new object

        let
          collectionName = getCollectionName(T)

        var fetched: Bson
        try:
          fetched = normDb.find(collectionName, @@{"_id": id}).returnOne()
        except NotFound:
          result = none(T)
          return
        var inner = T()
        applyBson(inner, fetched)
        result = some inner

      proc getOneOption(T: typedesc, cond: Bson): Option[T] {.used.} =
        ## Read a record from DB by search condition and return a new object

        let
          collectionName = getCollectionName(T)

        var fetched: Bson
        try:
          fetched = normDb.find(collectionName, cond).returnOne()
        except NotFound:
          result = none(T)
          return
        var inner = T()
        applyBson(inner, fetched)
        result = some inner

      proc getMany(
        T: typedesc,
        nLimit: int,
        cond = @@{},
        sort = @@{},
        offset = 0
      ): seq[T] {.used.} =
        let
          collectionName = getCollectionName(T)
          fetched = normDb.find(collectionName, cond).skip(offset.int32).sort(sort).limit(nLimit.int32).returnMany()
        for doc in fetched:
          var temp = T()
          applyBson(temp, doc)
          result.add temp

      proc getMany(
        objs: var seq[object],
        nLimit: int,
        cond = @@{},
        sort = @@{},
        offset = 0
      ) {.used.} =
        objs = type(objs[^1]).getMany(nLimit, cond, sort, offset)  # this works even on an empty list; which is surprising!


      proc update(obj: object, force = false): bool {.used, discardable.} =
        ##[ Update document with matching ``_id`` with object field values.

        ``force`` parameter ignored.

        returns true if update was successful.
        ]##

        let
          collectionName = getCollectionName(type(obj))
        var doc = obj.toBson()
        # let response = waitFor(dbCollection.update(@@{"_id": obj.id}, doc, false, false))
        let ctr = normDb.replaceOne(collectionName, @@{"_id": obj.id}, doc, false)
        if ctr == 1:
          return true
        return false

      proc delete(obj: var object): bool {.used, discardable.} =
        ## Delete a record in DB by object's id. The id is set to all zeroes after the deletion.

        let
          collectionName = getCollectionName(type(obj))
        try:
          discard normDb.deleteOne(collectionName, @@{"_id": obj.id})
        except NotFound:
          return false
        return true

      try:
        body
      finally:
        releaseConnection(normDb)


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
  ##[
    For the node passed in, generate a normalized string representation of the type.

    This function handles both plain types as well as compound types such as seq[T] and Option[T].
  ]##
  if n.kind in @[nnkIdent, nnkSym]:
    result = $n
  elif n.kind == nnkBracketExpr:
    var inner = ""
    if n[1].kind == nnkBracketExpr:
      inner = reconstructType(n[1])
    else:
      inner = $n[1]
    result = "$1[$2]".format($n[0], inner)
  else:
    result = "unknown"

proc seqTypeNames(name: string): seq[string] = 
  ##[
    Turn a bracketed string type and turn it into a sequence of elements.
    For example: seq[Option[int]] would become @["seq", "Option", "int"]
  ]##
  var
    s = name
    temp: seq[string] 

  while true:
    if '[' in s:
      temp = split(s, '[', 1)
      result.add temp[0]
      if len(temp)==1:
        break
      s = temp[1]
      if ']' in s:
        temp = rsplit(s, ']', 1)
        s = temp[0]
    else:
      break
      
  result.add s

proc restoreSeqType(s: seq[string]): string = 
  ##[
    The opposite of seqTypeNames, turns a sequence of parts back
    into a string. Used for building intermediate conditions in applyBson.
  ]##
  var
    temp = reversed(s)
  for index, entry in temp.pairs():
    if index==0:
      result = entry
    else:
      result = "$1[$2]".format(entry, result)

proc updateObjectRegistry(dbObjReprs: seq[ObjRepr]) {.compileTime.} =
  ##[
    Add a new entry in into the global variable `normObjectNamesRegistry`.

    This registry only exists at compile-time and is used by various
    macros.
  ]##
  var objName: string
  for obj in dbObjReprs:
    objName = obj.signature.name
    if not normObjectNamesRegistry.contains(objName):
      normObjectNamesRegistry.add objName

proc genBasicToBson(srcField, dest, typeName: string, tab: int, fromSeq = false): string =
  let t = spaces(tab)
  if typeName == "Oid":
    result &= t & "if $$$1 != \"000000000000000000000000\":\n".format(srcField)
    result &= t & "  $1 = toBson($2)\n".format(dest, srcField)
  elif typeName == "Time":
    result &= t & "if $1 != fromUnix(0):\n".format(srcField)
    result &= t & "  $1 = toBson($2)\n".format(dest, srcField)
  else:
    result &= t & "$1 = toBson($2)\n".format(dest, srcField)


proc genSeqToBson(fieldName, dest: string, typeList: seq[string], tab: int): string
proc genNToBson(fieldName, dest: string, typeList: seq[string], tab: int): string

proc genOptionToBson(fieldName, dest: string, typeList: seq[string], tab: int): string =
  let t = spaces(tab)
  if len(typeList) < 2:
    raise newException(
      KeyError, 
      "$1 as malformed type $2 at depth $3".format(fieldName, $typeList, tab)
    )
  let nextType = typeList[1]
  result &= t & "if $1.isNone:\n".format(fieldName)
  result &= t & "  $1 = null()\n".format(dest)
  result &= t & "else:\n"
  if nextType == "Option":
    result &= genOptionToBson("$1.get()".format(fieldName), dest, typeList[1 .. typeList.high], tab+2)
  elif nextType == "seq":
    result &= genSeqToBson("$1.get()".format(fieldName), dest, typeList[1 .. typeList.high], tab+2)
  elif nextType in normBasicTypeList:
    result &= genBasicToBson("$1.get()".format(fieldName), dest, nextType, tab+2)
  elif nextType in normObjectNamesRegistry:
    result &= t & "  $1 = $2.get().toBson()\n".format(dest, fieldName)
  elif nextType == "N":
    result &= genNToBson("$1.get()".format(fieldName), dest, typeList[1 .. typeList.high], tab+2)
  else:
    raise newException(
      KeyError, 
      "Field \"$1\"'s type of $2 is not known to norm/mongodb[1].".format(fieldName, nextType)
    )

proc genNToBson(fieldName, dest: string, typeList: seq[string], tab: int): string =
  let t = spaces(tab)
  if len(typeList) < 2:
    raise newException(
      KeyError, 
      "$1 as malformed type $2 at depth $3".format(fieldName, $typeList, tab)
    )
  let nextType = typeList[1]
  result &= t & "if $1.isNull:\n".format(fieldName)
  result &= t & "  $1 = null()\n".format(dest)
  result &= t & "elif $1.isNothing:\n".format(fieldName)
  result &= t & "  discard\n".format(dest)
  result &= t & "elif $1.hasError:\n".format(fieldName)
  result &= t & "  $1 = null()\n".format(dest)
  result &= t & "else:\n"
  if nextType == "Option":
    result &= genOptionToBson("$1.getValue()".format(fieldName), dest, typeList[1 .. typeList.high], tab+2)
  elif nextType == "seq":
    result &= genSeqToBson("$1.getValue()".format(fieldName), dest, typeList[1 .. typeList.high], tab+2)
  elif nextType in normBasicTypeList:
    result &= genBasicToBson("$1.getValue()".format(fieldName), dest, nextType, tab+2)
  elif nextType in normObjectNamesRegistry:
    result &= t & "  $1 = $2.get().toBson()\n".format(dest, fieldName)
  elif nextType == "N":
    result &= genNToBson("$1.getValue()".format(fieldName), dest, typeList[1 .. typeList.high], tab+2)
  else:
    raise newException(
      KeyError, 
      "Field \"$1\"'s type of $2 is not known to norm/mongodb[2].".format(fieldName, nextType)
    )

proc genSeqToBson(fieldName, dest: string, typeList: seq[string], tab: int): string =
  let t = spaces(tab)

  if len(typeList) < 2:
    raise newException(
      KeyError, 
      "$1 as malformed type $2 at depth $3".format(fieldName, $typeList, tab)
    )
  let nextType = typeList[1]
  let entry = nextVar("entry")
  let inner = nextVar("inner")
  # let innerTypeName = restoreSeqType(typeList[1 .. typeList.high])

  result &= t & "$1 = newBsonArray()\n".format(dest)
  result &= t & "for $1 in $2:\n".format(entry, fieldName)
  if nextType == "Option":
    result &= t & "  var $1 = null()\n".format(inner)
    result &= genOptionToBson(entry, inner, typeList[1 .. typeList.high], tab+2)
  elif nextType == "seq":
    result &= t & "  var $1 = null()\n".format(inner)
    result &= genSeqToBson(entry, inner, typeList[1 .. typeList.high], tab+2)
  elif nextType in normBasicTypeList:
    result &= t & "  var $1 = null()\n".format(inner)
    result &= genBasicToBson(entry, inner, nextType, tab+2, fromSeq=true)
  elif nextType in normObjectNamesRegistry:
    result &= t & "  var $1 = toBson($2, force)\n".format(inner, entry)
  elif nextType == "N":
    result &= genNToBson(entry, inner, typeList[1 .. typeList.high], tab+2)
  else:
    raise newException(
      KeyError, 
      "Field \"$2\"'s type of $2 is not known to norm/mongodb[3].".format(fieldName, nextType)
    )
  result &= t & "  $1.add $2\n".format(dest, inner)


proc genObjectToBson(dbObjReprs: seq[ObjRepr]): string =
  ##[
  this procedure generates new procedures the convert the values in an
  existing "type" object to a BSON object.

  So, for example, with object defined as:

  ```
  type
    Pet = object
      shortName: string
    User = object
      displayName: string
      weight: Option[float]
      thePet: Pet
  ```

  you will get a string containing procedures similar to:

  ```
  proc toBson(obj: Pet, force = false): Bson {.used.} =
    result = newBsonDocument()

    result["shortName"] = toBson(obj.shortName)

  proc toBson(obj: User, force = false): Bson {.used.} =
    result = newBsonDocument()

    result["displayName"] = toBson(obj.displayName)
    if obj.weight.isNone:
      result["weight"] = null()
    else:
      result["weight"] = toBson(obj.weight.get())
    result["thePet"] = toBson(obj.thePet, force)
  ```
  ]##
  var
    proc_map = initOrderedTable[string, string]() # object: procedure string
    objectName = ""
    fullTypeName = ""
    typeName = ""
    fieldName = ""
    bsonFieldName = ""
    key = ""
    tab = 2
    typeList: seq[string] = @[]

  #
  # generate one toBson per object
  #
  for obj in dbObjReprs:
    objectName = obj.signature.name
    key = objectName
    proc_map[key] =  "proc toBson(obj: $1, force = false): Bson {.used.} =\n".format(objectName)
    proc_map[key] &= "  result = newBsonDocument()\n"
    proc_map[key] &= "\n"
    #
    for field in obj.fields:
      fullTypeName = reconstructType(field.typ)
      typeList = seqTypeNames(fullTypeName)
      typeName = typeList[0]
      fieldName = field.signature.name
      bsonFieldName = fieldName
      for p in field.signature.pragmas:
        if p.name=="dbCol":
          bsonFieldName = $p.value
      if normBasicTypeList.contains(typeName):
        proc_map[key] &= genBasicToBson("obj.$1".format(fieldName), "result[\"$1\"]".format(bsonFieldName), typeName, tab)
      elif typeName=="seq":
        proc_map[key] &= genSeqToBson("obj.$1".format(fieldName), "result[\"$1\"]".format(bsonFieldName), typeList, tab)
      elif typeName=="Option":
        proc_map[key] &= genOptionToBson("obj.$1".format(fieldName), "result[\"$1\"]".format(bsonFieldName), typeList, tab)
      elif typeName=="N":
        proc_map[key] &= genNToBson("obj.$1".format(fieldName), "result[\"$1\"]".format(bsonFieldName), typeList, tab)
      else:
        if normObjectNamesRegistry.contains(typeName):
          proc_map[key] &= "  result[\"$1\"] = toBson(obj.$1, force)\n".format(fieldName)
        else:
          raise newException(
            KeyError, 
            "In object $1, the field $2's type is not known to norm/mongodb[4]. If it is a subtending object, is $3 defined by dB, dbAddCollection, or dbAddObject yet?".format(objectName, fieldName, typeName)
          )
  #
  # finish up all procedure strings
  #
  for key, s in proc_map.pairs():
    result &= s
    result &= "\n" # add a blank line between each proc


proc genBsonToBasic(
  src, fieldName, typeName: string, 
  tab: int,
  skipCheck = false, 
  fromSeq = false,
  fromOption = false,
  fromN = false
): string =
  let t = spaces(tab)
  var assignment = " ="
  if fromOption:
    assignment &= " some"
  if fromN:
    assignment = ".set"
  if skip_check:
    result &= t & "if $1.kind in @[$2]:\n".format(src, normTypeToBsonKind[typeName])
    result &= t & "  $1$2 $3.$4\n".format(fieldName, assignment, src, normTypeToBsonProc[typeName])
  else:
    result &= t & "if not $1.isNil:\n".format(src)
    result &= t & "  if $1.kind in @[$2]:\n".format(src, normTypeToBsonKind[typeName])
    result &= t & "    $1$2 $3.$4\n".format(fieldName, assignment, src, normTypeToBsonProc[typeName])

proc genBsonToSeq(src, fieldName: string, typeList: seq[string], tab:int, skipCheck=false, fromSeq=false, fromOption=false): string
proc genBsonToN(src, fieldName: string, typeList: seq[string], tab:int, skipCheck=false, fromSeq=false, fromOption=false): string

proc genBsonToOption(src, fieldName: string, typeList: seq[string], tab:int, skipCheck=false, fromSeq=false, fromOption=false): string =
  let t = spaces(tab)

  if len(typeList) < 2:
    raise newException(
      KeyError, 
      "$1 has a malformed type $2 at depth $3".format(fieldName, $typeList, tab)
    )
  let nextType = typeList[1]
  let subTypeName = restoreSeqType(typeList[1 .. typeList.high])
  var assignment = " ="

  # result &= t & "# INSIDE genBsonToOption Option next=$1\n".format(nextType)

  if skipCheck:
    result &= t & "if $1.kind == BsonKindNull:\n".format(src)
    result &= t & "  $1$2 none($3)\n".format(fieldName, assignment, subTypeName)
    if nextType in normBasicTypeList:
      result &= genBsonToBasic(
        src,
        fieldName,
        nextType,
        tab,
        skipCheck=true,
        fromSeq=fromSeq,
        fromOption=true,
        fromN=false
      )
    elif nextType in normObjectNamesRegistry:
      let temp = nextVar("temp")
      result &= t & "else:\n"
      result &= t & "  var $1: $2\n".format(temp, subTypeName)
      result &= t & "  applyBson($1, $2)\n".format(temp, src)
      result &= t & "  $1$2 some $3\n".format(fieldName, assignment, temp)
    elif nextType=="seq":
      result &= t & "else:\n"
      let temp = nextVar("temp")
      result &= t & "  var $1: $2\n".format(temp, subTypeName)
      result &= genBsonToSeq(
        src, 
        temp, 
        typeList[1 .. typeList.high],
        tab+2,
        skipCheck=true,
        fromSeq=fromSeq,
        fromOption=true
      )
      result &= t & "  $1 = some $2\n".format(fieldName, temp)
    elif nexttype=="Option":
      raise newException(RangeError, "MongoDb library cannot directly nested Option[Option[T]] sequences as they are not translatable to BSON. (Option[$1])".format(subTypeName))
    elif nexttype=="N":
      result &= t & "else:\n"
      let temp = nextVar("temp")
      result &= t & "  var $1: $2\n".format(temp, subTypeName)
      result &= genBsonToN(
        src, 
        temp, 
        typeList[1 .. typeList.high],
        tab+2,
        skipCheck=true,
        fromSeq=fromSeq,
        fromOption=true
      )
      result &= t & "  $1 = some $2\n".format(fieldName, temp)
  else:
    result &= t & "if not $1.isNil:\n".format(src)
    result &= t & "  if $1.kind == BsonKindNull:\n".format(src)
    result &= t & "    $1$2 none($3)\n".format(fieldName, assignment, subTypeName)
    if nextType in normBasicTypeList:
      result &= genBsonToBasic(
        src,
        fieldName,
        nextType,
        tab+2,
        skipCheck=true,
        fromSeq=fromSeq,
        fromOption=true,
        fromN=false
      )
    elif nextType in normObjectNamesRegistry:
      let temp = nextVar("temp")
      result &= t & "  else:\n"
      result &= t & "    var $1: $2\n".format(temp, subTypeName)
      result &= t & "    applyBson($1, $2)\n".format(temp, src)
      result &= t & "    $1$2 some $3\n".format(fieldName, assignment, temp)
    elif nextType=="seq":
      let temp = nextVar("temp")
      result &= t & "  else:\n"
      result &= t & "    var $1: $2\n".format(temp, subTypeName)
      result &= genBsonToSeq(
        src, 
        temp, 
        typeList[1 .. typeList.high],
        tab+4,
        skipCheck=true,
        fromSeq=fromSeq,
        fromOption=true
      )
      result &= t & "    $1 = some $2\n".format(fieldName, temp)
    elif nexttype=="Option":
      raise newException(RangeError, "MongoDb library cannot directly nested Option[Option[T]] sequences as they are not translatable to BSON. (Option[$1])".format(subTypeName))
    elif nexttype=="N":
      let temp = nextVar("temp")
      result &= t & "  else:\n"
      result &= t & "    var $1: $2\n".format(temp, subTypeName)
      result &= genBsonToN(
        src, 
        temp, 
        typeList[1 .. typeList.high],
        tab+4,
        skipCheck=true,
        fromSeq=fromSeq,
        fromOption=true
      )
      result &= t & "    $1 = some $2\n".format(fieldName, temp)

proc genBsonToN(src, fieldName: string, typeList: seq[string], tab:int, skipCheck=false, fromSeq=false, fromOption=false): string =
  let t = spaces(tab)

  if len(typeList) < 2:
    raise newException(
      KeyError, 
      "$1 has a malformed type $2 at depth $3".format(fieldName, $typeList, tab)
    )
  let nextType = typeList[1]
  let subTypeName = restoreSeqType(typeList[1 .. typeList.high])
  var assignment = " ="

  # result &= t & "# INSIDE genBsonToOption Option next=$1\n".format(nextType)

  if skipCheck:
    result &= t & "if $1.kind == BsonKindNull:\n".format(src)
    result &= t & "  $1$2 null($3)\n".format(fieldName, assignment, subTypeName)
    if nextType in normBasicTypeList:
      result &= genBsonToBasic(
        src,
        fieldName,
        nextType,
        tab,
        skipCheck=true,
        fromSeq=fromSeq,
        fromOption=false,
        fromN=true
      )
    elif nextType in normObjectNamesRegistry:
      let temp = nextVar("temp")
      result &= t & "else:\n"
      result &= t & "  var $1: $2\n".format(temp, subTypeName)
      result &= t & "  applyBson($1, $2)\n".format(temp, src)
      result &= t & "  $1$2 $3\n".format(fieldName, assignment, temp)
    elif nextType=="seq":
      let temp = nextVar("temp")
      result &= t & "  var $1: $2\n".format(temp, subTypeName)
      result &= genBsonToSeq(
        src, 
        temp, 
        typeList[1 .. typeList.high],
        tab,
        skipCheck=true,
        fromSeq=fromSeq,
        fromOption=false
      )
      result &= t & "  $1 = $2\n".format(fieldName, temp)
    elif nexttype=="Option":
      let temp = nextVar("temp")
      result &= t & "  var $1: $2\n".format(temp, subTypeName)
      result &= genBsonToOption(
        src, 
        temp, 
        typeList[1 .. typeList.high],
        tab,
        skipCheck=true,
        fromSeq=fromSeq,
        fromOption=false
      )
      result &= t & "  $1 = $2\n".format(fieldName, temp)
    elif nexttype=="N":
      let temp = nextVar("temp")
      result &= t & "  var $1: $2\n".format(temp, subTypeName)
      result &= genBsonToN(
        src, 
        temp, 
        typeList[1 .. typeList.high],
        tab,
        skipCheck=true,
        fromSeq=fromSeq,
        fromOption=false
      )
      result &= t & "  $1 = $2\n".format(fieldName, temp)
  else:
    result &= t & "if $1.isNil:\n".format(src)
    result &= t & "  $1$2 nothing($3)\n".format(fieldName, assignment, subTypeName)
    result &= t & "else:\n"
    result &= t & "  if $1.kind == BsonKindNull:\n".format(src)
    result &= t & "    $1$2 null($3)\n".format(fieldName, assignment, subTypeName)
    if nextType in normBasicTypeList:
      result &= genBsonToBasic(
        src,
        fieldName,
        nextType,
        tab+2,
        skipCheck=true,
        fromSeq=fromSeq,
        fromOption=false,
        fromN=true
      )
    elif nextType in normObjectNamesRegistry:
      let temp = nextVar("temp")
      result &= t & "  else:\n"
      result &= t & "    var $1: $2\n".format(temp, subTypeName)
      result &= t & "    applyBson($1, $2)\n".format(temp, src)
      result &= t & "    $1$2 $3\n".format(fieldName, assignment, temp)
    elif nextType=="seq":
      let temp = nextVar("temp")
      result &= t & "  var $1: $2\n".format(temp, subTypeName)
      result &= genBsonToSeq(
        src, 
        temp, 
        typeList[1 .. typeList.high],
        tab+2,
        skipCheck=true,
        fromSeq=fromSeq,
        fromOption=false
      )
      result &= t & "  $1 = $2\n".format(fieldName, temp)
    elif nexttype=="Option":
      let temp = nextVar("temp")
      result &= t & "  var $1: $2\n".format(temp, subTypeName)
      result &= genBsonToOption(
        src, 
        temp, 
        typeList[1 .. typeList.high],
        tab+2,
        skipCheck=true,
        fromSeq=fromSeq,
        fromOption=false
      )
      result &= t & "  $1 = $2\n".format(fieldName, temp)
    elif nexttype=="N":
      let temp = nextVar("temp")
      result &= t & "  var $1: $2\n".format(temp, subTypeName)
      result &= genBsonToN(
        src, 
        temp, 
        typeList[1 .. typeList.high],
        tab+2,
        skipCheck=true,
        fromSeq=fromSeq,
        fromOption=false
      )
      result &= t & "  $1 = $2\n".format(fieldName, temp)

proc genBsonToSeq(src, fieldName: string, typeList: seq[string], tab:int, skipCheck=false, fromSeq=false, fromOption=false): string =
  let t = spaces(tab)

  if len(typeList) < 2:
    raise newException(
      KeyError, 
      "$1 has a malformed type $2 at depth $3".format(fieldName, $typeList, tab)
    )
  let nextType = typeList[1]
  let subTypeName = restoreSeqType(typeList[1 .. typeList.high])
  let item = nextVar("item")
  # result &= t & "# INSIDE genBsonToSeq seq next=$1\n".format(nextType)
  let inner = nextVar("inner")
  if skipCheck:
    result &= t & "for $1 in $2.items:\n".format(item, src)
    result &= t & "  var $1: $2\n".format(inner, subTypeName)
    if nextType in normBasicTypeList:
      result &= genBsonToBasic(item, inner, nextType, tab+2, skipCheck=true, fromSeq=true)
    elif nextType in normObjectNamesRegistry:
      result &= t & "  applyBson($1, $2)\n".format(inner, item)
    elif nextType == "seq":
      result &= genBsontoSeq(item, inner, typeList[1 .. typeList.high], tab+2, skipCheck=true, fromSeq=false)
    elif nextType == "Option":
      result &= genBsontoOption(item, inner, typeList[1 .. typeList.high], tab+2, skipCheck=true, fromSeq=false)
    elif nextType == "N":
      result &= genBsontoN(item, inner, typeList[1 .. typeList.high], tab+2, skipCheck=true, fromSeq=false)
    result &= t & "  $1.add $2\n".format(fieldName, inner) # if we are in the loop, we ALWAYS add an item for each iteration
  else:
    result &= t & "if not $1.isNil:\n".format(src)
    result &= t & "  $1 = @[]\n".format(fieldName)
    result &= t & "  for $1 in $2.items:\n".format(item, src)
    result &= t & "    var $1: $2\n".format(inner, subTypeName)
    if nextType in normBasicTypeList:
      result &= genBsonToBasic(item, inner, nextType, tab+4, skipCheck=true, fromSeq=true)
    elif nextType in normObjectNamesRegistry:
      result &= t & "    applyBson($1, $2)\n".format(inner, item)
    elif nextType == "seq":
      result &= genBsontoSeq(item, inner, typeList[1 .. typeList.high], tab+4, skipCheck=true, fromSeq=true)
    elif nextType == "Option":
      result &= genBsontoOption(item, inner, typeList[1 .. typeList.high], tab+4, skipCheck=true, fromSeq=true)
    elif nextType == "N":
      result &= genBsontoN(item, inner, typeList[1 .. typeList.high], tab+4, skipCheck=true, fromSeq=true)
    result &= t & "    $1.add $2\n".format(fieldName, inner) # if we are in the loop, we ALWAYS add an item for each iteration

proc genBsonToObject(dbObjReprs: seq[ObjRepr]): string =
  ##[
  this procedure generates new procedures that map values found in an
  existing "type" object to a Bson object.

  So, for example, with object defined as:

  ```
  type
    Pet = object
      shortName: string
    User = object
      displayName: string
      weight: Option[float]
      thePet: Pet
  ```

  you will get a string containing procedures similar to:

  ```
  proc applyBson(obj: var Pet, doc: Bson) {.used.} =
    discard
    if not doc["shortName"].isNil:
      if doc["shortName"].kind in @[BsonKindStringUTF8]:
        obj.shortName = doc["shortName"].toString

  proc applyBson(obj: var User, doc: Bson) {.used.} =
    discard
    if not doc["displayName"].isNil:
      if doc["displayName"].kind in @[BsonKindStringUTF8]:
        obj.displayName = doc["displayName"].toString
    if not doc["weight"].isNil:
      if doc["weight"].kind == BsonKindNull:
        obj.weight = none(float)
      if doc["weight"].kind in @[BsonKindDouble]:
        obj.weight = some doc["weight"].toFloat64
    if doc.contains("thePet"):
      obj.thePet = Pet()
      applyBson(obj.thePet, doc["thePet"])
  ```
  ]##
  var
    proc_map = initOrderedTable[string, string]() # object: procedure string
    objectName = ""
    typeName = ""
    fieldName = ""
    bsonFieldName = ""
    key = ""

  #
  # now generate one applyBson per object
  #
  for obj in dbObjReprs:
    objectName = obj.signature.name
    key = objectName
    proc_map[key] =  "proc applyBson(obj: var $1, doc: Bson) {.used.} =\n".format(objectName)
    proc_map[key] &= "  if doc.kind != BsonKindDocument:\n"
    proc_map[key] &= "    return\n"
    #
    #
    for field in obj.fields:
      let fullTypeName = reconstructType(field.typ)
      var tseq = seqTypeNames(fullTypeName)
      typeName = tseq[0]
      fieldName = field.signature.name
      bsonFieldName = fieldName
      # proc_map[key] &= "  #START: $1\n".format($tseq)
      for p in field.signature.pragmas:
        if p.name=="dbCol":
          bsonFieldName = $p.value
      if typeName in normBasicTypeList:
        proc_map[key] &= genBsonToBasic(
          "doc[\"$1\"]".format(bsonFieldName), "obj.$1".format(fieldName), typeName, 2,
          skipCheck=false, fromSeq=false, fromOption=false
        )
      elif typeName=="seq":
        proc_map[key] &= genBsonToSeq(
          "doc[\"$1\"]".format(bsonFieldName), "obj.$1".format(fieldName), tseq, 2,
          skipCheck=false, fromSeq=false, fromOption=false
        )
      elif typeName=="Option":
        proc_map[key] &= genBsonToOption(
          "doc[\"$1\"]".format(bsonFieldName), "obj.$1".format(fieldName), tseq, 2,
          skipCheck=false, fromSeq=false, fromOption=false
        )
      elif typeName=="N":
        proc_map[key] &= genBsonToN(
          "doc[\"$1\"]".format(bsonFieldName), "obj.$1".format(fieldName), tseq, 2,
          skipCheck=false, fromSeq=false, fromOption=false
        )
      else:
        if normObjectNamesRegistry.contains(typeName):
          proc_map[key] &= "  if doc.contains(\"$1\"):\n".format(fieldName)
          proc_map[key] &= "    obj.$1 = $2()\n".format(fieldName, typeName)
          proc_map[key] &= "    applyBson(obj.$1, doc[\"$1\"])\n".format(fieldName)
  #
  # finish up all procedure strings
  #
  for key, s in proc_map.pairs():
    result &= s
    result &= "\n" # add a blank line between each proc


macro db*(connection, user, password, database: string, body: untyped): untyped =
  ##[
    DB models definition. Models are defined as regular Nim objects in regular ``type`` sections.

    ``connection``, ``user``, ``password``, ``database`` are the same args accepted by a standard ``dbConn`` instance.

    The macro generates ``withDb`` template that wraps all DB interations.
  ]##

  result = newStmtList()

  var dbObjReprs: seq[ObjRepr]
  var normObjectNamesRegistry: seq[string] = @[] # this is later injected into context
  var newCollections: seq[string]

  for node in body:
    if node.kind == nnkTypeSection:
      let typeSection = node.ensureIdFields()
      result.add typeSection

      for typeDef in typeSection:
        # echo typeDef.treeRepr
        dbObjReprs.add typeDef.toObjRepr()

    else:
      result.add node

  updateObjectRegistry(dbObjReprs)
  for o in dbObjReprs:
    newCollections.add o.getCollectionName

  # echo $dbObjReprs
  # echo $genObjectAccess(dbObjReprs)
  # let objectAccess =  parseStmt(genObjectAccess(dbObjReprs))
  # result.add(objectAccess)

  let withDbNode = getAst genWithDb(newCollections)
  result.insert(0, withDbNode)

  let bsonToObjectSource = genBsonToObject(dbObjReprs)
  # echo bsonToObjectSource
  let bsonToObject = parseStmt(bsonToObjectSource)
  result.add(bsonToObject)

  let objectToBsonSource = genObjectToBson(dbObjReprs)
  # echo objectToBsonSource
  let objectToBson = parseStmt(objectToBsonSource)
  result.add(objectToBson)

macro dbAddTable*(obj: typed): untyped =
  ##[
    Add a DB models for an object that has already been defined.

    The macro generates ``withDb`` template that wraps all DB interations.
  ]##
  result = newStmtList()

  let objName = $obj
  if normObjectNamesRegistry.contains(objName):
    raise newException(KeyError, "Macro dbAddCollection cannot add the same object again ($1).".format(objName))
  normObjectNamesRegistry.add objName

  var dbObjReprs: seq[ObjRepr]
  var newCollections: seq[string]

  let typeDef = getImpl(obj)

  dbObjReprs.add typeDef.toObjRepr()

  for o in dbObjReprs:
    newCollections.add o.getCollectionName
    # for objects added AFTER their type definition, check and make sure
    # the 'id' field exists since it is not possible to add it after-the-fact.
    var idFound = false
    for f in o.fields:
      if f.signature.name == "id":
        if f.signature.exported:
          for p in f.signature.pragmas:
            if p.name == "dbCol":
              if p.kind == pkKval:
                idFound = true
    if not idFound: 
      raise newException(KeyError, "Object ($1) is missing an exported 'id' field that has a dbCol pragma for '_id'.".format(objName))

  let withDbNode = getAst genWithDb(newCollections)
  result.insert(0, withDbNode)

  let bsonToObjectSource = genBsonToObject(dbObjReprs)
  # echo bsonToObjectSource
  let bsonToObject = parseStmt(bsonToObjectSource)
  result.add(bsonToObject)

  let objectToBsonSource = genObjectToBson(dbObjReprs)
  # echo objectToBsonSource
  let objectToBson = parseStmt(objectToBsonSource)
  result.add(objectToBson)

template dbAddCollection*(obj: typed): untyped =
  ##[
    Alias for dbAddTable
  ]##
  dbAddTable(obj)

macro dbAddObject*(obj: typed): untyped =
  ##[
    Add an object for use a subtending object.

    For example:

        type
          Address = object
            street: string
            city: string
            state: string
            postalCode: string

        dbAddObject(Address)

        db("127.0.0.1", "", "", "dbTest"):
          type
            User = object
              name: string
              age: int
              homeAddress: Address

    Without using dbAddObject, the library would not know how to handle the
    ``homeAddress`` field of ``User``.

    By using dbAddObject there will NOT be a collection called
    "address". Instead, the Address object will be strictly limited to use in
    other collections.

    Because nim is a single pass compiler, you will need to add these objects
    before they are referenced by later objects.
  ]##
  result = newStmtList()

  let objName = $obj
  if normObjectNamesRegistry.contains(objName):
    raise newException(KeyError, "Macro dbAddObject cannot add the same object again ($1).".format(objName))
  normObjectNamesRegistry.add objName

  var dbObjReprs: seq[ObjRepr]
  var newCollections: seq[string]

  let typeDef = getImpl(obj)
  dbObjReprs.add typeDef.toObjRepr()

  for o in dbObjReprs:
    newCollections.add o.getCollectionName

  let withDbNode = getAst addObjectsToCollection(newCollections)
  result.insert(0, withDbNode)

  let bsonToObjectSource = genBsonToObject(dbObjReprs)
  # echo bsonToObjectSource
  let bsonToObject = parseStmt(bsonToObjectSource)
  result.add(bsonToObject)

  let objectToBsonSource = genObjectToBson(dbObjReprs)
  # echo objectToBsonSource
  let objectToBson = parseStmt(objectToBsonSource)
  result.add(objectToBson)
