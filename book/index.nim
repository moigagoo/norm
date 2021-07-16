import nimib, nimibook


nbInit
nbUseNimibook

nbText: """
# Welcome to Norm!

**Norm** is an object-driven, framework-agnostic ORM for Nim that supports SQLite and PostgreSQL.

-   [Repo](https://github.com/moigagoo/norm)

    -   [Issues](https://github.com/moigagoo/norm/issues)
    -   [Pull requests](https://github.com/moigagoo/norm/pulls)

-   [API index](https://norm.nim.town/theindex.html)
-   [Changelog](https://github.com/moigagoo/norm/blob/develop/changelog.rst)


## Installation

Install Norm with [Nimble](https://github.com/nim-lang/nimble):

    $ nimble install -y norm

Add Norm to your .nimble file:

    requires "norm"
"""

nbSave
