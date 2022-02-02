import norm/pragmasutils
import std/unittest

template p() {.pragma.}
template parg(s: string) {.pragma.}
type
  A[T] = object
    a {.p.}: int
    a2 {.parg: "Cat".}: int

  B = object
    b {.p.}: int
    b2 {.parg: "Dog".}: int

  C {.parg: "Mouse".} = B

proc main() =
  test "custom_pragma":
    var a: A[int]
    static:
      doAssert a.a.hasCustomPragma(p)
      doAssert not a.a.hasCustomPragma(A)

    check a.a.hasCustomPragma(p)
    check not a.a.hasCustomPragma(A)
    check a.a2.getCustomPragmaVal(parg) == "Cat"

    var b: B
    static:
      doAssert b.b.hasCustomPragma(p)
      doAssert not b.b.hasCustomPragma(B)
      doAssert not b.b.hasCustomPragma(C)

    check b.b.hasCustomPragma(p)
    check not b.b.hasCustomPragma(B)
    check not b.b.hasCustomPragma(C)
    check b.b2.getCustomPragmaVal(parg) == "Dog"
    var c: C
    check c.b2.getCustomPragmaVal(parg) == "Dog"
    const x = C.getCustomPragmaVal(parg)
    check x == "Mouse"


main()
