#[
# Test
]#

import norm/pragmas
template p() {.pragma.}

type
  A[T] = object
    a {.p.}: int

  B = object
    b {.p.}: int


proc main() =
  var a: A[int]
  static:
    doAssert a.a.hasCustomPragma(p)
    doAssert not a.a.hasCustomPragma(A)

  var b: B
  static:
    doAssert b.b.hasCustomPragma(p)
    doAssert not b.b.hasCustomPragma(B)

main()
#[
# End Test
]#


