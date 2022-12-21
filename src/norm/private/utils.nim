import std/options


func isRefObject*[T](val: typedesc[T]): bool {.compileTime.} =
  ## Checks if a given type is of type ref object
  T is ref object

func isRefObject*[T](val: T): bool {.compileTime.} =
  ## Checks if a given variable is of type ref object
  T is ref object

func isRefObject*[T](val: typedesc[Option[T]]): bool {.compileTime.} =
  ## Checks if the inner type of an given optional type is a ref object
  T is ref object

func isRefObject*[T](val: Option[T]): bool {.compileTime.} =
  ## Checks if the inner type of the optional variable is a ref object
  T is ref object

func toOptional*[T: ref object](val: T): Option[T] =
  ## Converts non optional type to optional type
  some val

func toOptional*[T: ref object](val: Option[T]): Option[T] =
  ## Convert optional type to optional type, doing effectively nothing
  val

