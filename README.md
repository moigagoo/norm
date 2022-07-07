# Welcome to Norm!

**Norm** is an object-driven, framework-agnostic ORM for Nim that supports SQLite and PostgreSQL.

- [Documentation](https://norm.nim.town/) (built with [nimibook](https://github.com/pietroppeter/nimibook))
- [API index](https://norm.nim.town/apidocs/theindex.html)
- [norman](https://github.com/moigagoo/norman): scaffolder and migration manager for Norm
- [shopapp](https://github.com/moigagoo/shopapp): a proof-of-concept for a webapp created with Karax for frontend, Jester for API server, Norm for ORM, and Norman for migration management 

## Installation

Install Norm with [Nimble](https://github.com/nim-lang/nimble):

    $ nimble install -y norm

Add Norm to your .nimble file:

    requires "norm"


## Contributing

Any contributions are welcome: pull requests, code reviews, documentation improvements, bug reports, and feature requests.

-   See the [issues on GitHub](http://github.com/moigagoo/norm/issues).

-   Run the tests before and after you change the code.

    The recommended way to run the tests is with Docker Compose:

        $ docker-compose run --rm tests                         # run all test suites
        $ docker-compose run --rm test tests/common/tmodel.nim  # run a single test suite

-   Use camelCase instead of snake_case.

-   New procs must have a documentation comment. If you modify an existing proc, update the comment.

-   Apart from the code that implements a feature or fixes a bug, PRs are required to ship necessary tests and a changelog updates.


## ❤ Contributors ❤

Norm would not be where it is today without the efforts of these fine folks: [https://github.com/moigagoo/norm/graphs/contributors](https://github.com/moigagoo/norm/graphs/contributors).
