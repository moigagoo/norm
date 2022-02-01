#[
# Test
]#

import norm/pragmasutils
template p() {.pragma.}

type
  A[T] = object
    a {.p.}: int

  B = object
    b {.p.}: int
  # Currently does not work : see PR https://github.com/nim-lang/Nim/pull/19451
  # C[T] = B

proc main() =
  var a: A[int]
  static:
    doAssert a.a.hasCustomPragma(p)
    doAssert not a.a.hasCustomPragma(A)

  var b: B
  static:
    doAssert b.b.hasCustomPragma(p)
    doAssert not b.b.hasCustomPragma(B)
    # doAssert not b.b.hasCustomPragma(C)

main()
#[
# End Test
]#


