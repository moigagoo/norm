import std/[options, strutils, typetraits, strformat]
import private/dot
import pragmas

when (NimMajor, NimMinor) <= (1, 6):
  import pragmasutils
else:
  import std/macros

type
  Model* = ref object of RootObj
    ##[ Base type for models.

    ``id`` corresponds to row id in DB. **Updated automatically, do not update manually!**
    ]##

    id* {.pk, ro.}: int64


func isModel*[T: Model](val: T): bool = true

func isModel*[T: Model](val: Option[T]): bool = true

func isModel*[T](val: T): bool = false

func model*[T: Model](val: T): Option[T] = some val

func model*[T: Model](val: Option[T]): Option[T] = val

func model*[T](val: T): Option[Model] =
  ## This is never called and exists only to please the compiler.

  none Model

func table*(T: typedesc[Model]): string =
  ## Get table name for `Model <#Model>`_, which is the type name in single quotes.

  when T.hasCustomPragma(tableName):
    '"' & T.getCustomPragmaVal(tableName) & '"'
  else:
    '"' & $T & '"'

func col*(T: typedesc[Model], fld: string): string =
  ## Get column name for a `Model`_ field, which is just the field name.

  fld

func col*[T: Model](obj: T, fld: string): string =
  ## Get column name for a `Model`_ instance field.

  T.col(fld)

func fCol*(T: typedesc[Model], fld: string): string =
  ## Get fully qualified column name for a `Model`_ field: ``table.col``.

  "$#.$#" % [T.table, T.col(fld)]

func fCol*[T: Model](obj: T, fld: string): string =
  ## Get fully qualified column name for a `Model`_ instance field.

  T.fCol(fld)

func fCol*(T: typedesc[Model], fld, tAls: string): string =
  ## Get fully qualified column name with an alias instead of the actual table name: ``alias.col``.

  "$#.$#" % [tAls, T.col(fld)]

func fCol*[T: Model](obj: T, fld, tAls: string): string =
  ## Get fully qualified column name with an alias instead of the actual table name for a `Model`_ instance field.

  T.fCol(fld, tAls)

func cols*[T: Model](obj: T, force = false): seq[string] =
  ##[ Get columns for `Model`_ instance.

  If ``force`` is ``true``, fields with `ro <pragmas.html#ro.t>`_ are included.
  ]##

  for fld, val in obj[].fieldPairs:
    if force or not obj.dot(fld).hasCustomPragma(ro):
      result.add obj.col(fld)

func rfCols*[T: Model](obj: T, flds: seq[string] = @[]): seq[string] =
  ## Recursively get fully qualified column names for `Model`_ instance and its `Model`_ fields.

  for fld, val in obj[].fieldPairs:
    result.add if len(flds) == 0: obj.fCol(fld) else: obj.fCol(fld, """"$#"""" % flds.join("_"))

    if val.isModel and val.model.isSome:
      result.add (get val.model).rfCols(flds & fld)

func joinGroups*[T: Model](obj: T, flds: seq[string] = @[]): seq[tuple[tbl, tAls, lFld, rFld: string]] =
  ##[ For each `Model`_ field of `Model`_ instance, get:
  - table name for the field type
  - full column name for the field
  - full column name for ``id`` field of the field type

  Used to construct ``JOIN`` statements: ``JOIN {tbl} AS {tAls} ON {lFld} = {rFld}``
  ]##

  for fld, val in obj[].fieldPairs:
    if val.model.isSome:
      let
        subMod = get val.model
        tbl = typeof(subMod).table
        tAls = """"$#"""" % (flds & fld).join("_")
        ptAls = if len(flds) == 0: typeof(obj).table else: """"$#"""" % flds.join("_")
        lFld = obj.fCol(fld, ptAls)
        rFld = subMod.fCol("id", tAls)
        grp = (tbl: tbl, tAls: tAls, lFld: lFld, rFld: rFld)

      result.add grp & subMod.joinGroups(flds & fld)

proc checkRo*(T: typedesc[Model]) =
  ## Stop compilation if an object has `ro`_ pragma.

  when T.hasCustomPragma(ro):
    {.error: "can't use mutating procs with read-only models".}

proc getRelatedFieldNameTo*[S: Model, T: Model](source: typedesc[S], target: typedesc[T]): string {.compileTime.} =
  ## A compile time proc that searches the given `source` Model type for any 
  ## foreign key field that points to the table of the `target`model type. 
  ## Breaks at compile time if `source`does not have exactly one foreign key 
  ## field to that table, as otherwise the desired field name to use can't
  ## be inferred.
  var fieldNames: seq[string] = @[]
  
  const targetTableName = T.table()
  for sourceFieldName, sourceFieldValue in S()[].fieldPairs:
      #Handles case where field is an int64 with fk pragma
      when sourceFieldValue.hasCustomPragma(fk):
        when targetTableName == sourceFieldValue.getCustomPragmaVal(fk).table():
          fieldNames.add(sourceFieldName)
      
      #Handles case where field is a Model type
      elif sourceFieldValue is Model:
        when targetTableName == sourceFieldValue.type().table():
          fieldNames.add(sourceFieldName)
      
      #Handles case where field is a Option[Model] type
      elif sourceFieldValue is Option:
        when sourceFieldValue.get() is Model:
          when targetTableName == genericParams(sourceFieldValue.type()).get(0).table():
              fieldNames.add(sourceFieldName)

  const sourceModelName = name(S)
  assert(not (fieldNames.len() < 1), fmt "Tried getting foreign key field from model '{sourceModelName}' to model '{targetTableName}' but there is no such field!")
  assert(not (fieldNames.len() > 1), fmt "Can't infer foreign key field from model '{sourceModelName}' to model '{targetTableName}'! There is more than one foreign key field to that table! {fieldNames.len}")

  return fieldNames[0]

proc validateFkField*[S, T: Model](fkFieldName: static string, source: typedesc[S], target: typedesc[T]): bool {.compileTime.} =
  ## Checks at compile time whether the field with the name `fkFieldName` is a 
  ## valid foreign key field on the given `source` model to the table of the given 
  ## `target` model. 
  ## Specifically checks 1) if the field exists, 2) if it has either an fk pragma, 
  ## or is a model type or an option of a model type, and 3) if the table associated
  ## with that field is equivalent to that of the table of the `target` model.
  ## If any of these conditions are false, this proc will intentionally fail to compile
  const sourceName = name(S)
  const targetTableName = table(T)
  assert(S.hasField(fkFieldName), fmt "Tried using '{fkFieldName}' as FK field from Model '{sourceName}' to table '{targetTableName}' but there was no such field")

  for sourceFieldName, sourceFieldValue in source()[].fieldPairs:
    when sourceFieldName == fkFieldName:
      #Handles case where field is an int with fk pragma
      when sourceFieldValue.hasCustomPragma(fk):
        const fkFieldTable: string = sourceFieldValue.getCustomPragmaVal(fk).table()

      #Handles case where field is a Model type
      elif sourceFieldValue is Model:
        const fkFieldTable: string = sourceFieldValue.type.table()
      
      #Handles case where field is a Option[Model] type
      elif sourceFieldValue is Option:
        when sourceFieldValue.get() is Model:
          const fkFieldTable: string = sourceFieldValue.get().type.table()
        else:
          assert(false, fmt "Tried using '{fkFieldName}' as FK field from Model '{sourceName}' to table '{targetTableName}' but it was an option of a type that wasn't a model")

      #Fail at compile time if any other case occurs
      else:
        assert(false, fmt "Tried using '{fkFieldName}' as FK field from Model '{sourceName}' to table '{targetTableName}' but it didn't have an fk pragma and was neither a model type, nor an option of a model type")

      assert((targetTableName == fkFieldTable),  fmt "Tried using '{fkFieldName}' as FK field from Model '{sourceName}' to table '{targetTableName}' but the pragma pointed to a different table '{fkFieldTable}'")
      return true

  return false

proc validateJoinModelFkField*[S, T: Model](fkFieldName: static string, joinModel: typedesc[S], target: typedesc[T]): bool {.compileTime.} =
  ## Checks at compile time whether the field with the name `fkFieldName` is a 
  ## valid foreign key field on the given `joinModel` model to the given 
  ## `target` model. Ensures that the type in the field `fkFieldName` is `target` 
  ## If it isn't the code won't compile as that Model type is required for a useful
  ## Many-To-Many query.
  let tmp = validateFkField(fkFieldName, joinModel, target)
  
  for joinFieldName, joinFieldValue in joinModel()[].fieldPairs:
    when joinFieldName == fkFieldName:
      #Handles case where field is an int with fk pragma
      const joinModelName = name(joinModel)
      const targetModelName = name(target)
      const actualType = name(joinFieldValue.type())
      assert(joinFieldValue is target, fmt"Tried using an invalid join model. Field '{joinModelName}.{fkFieldName}' was not of the required type `{targetModelName}`, but of type `{actualType}`!")

      return true

  return false
