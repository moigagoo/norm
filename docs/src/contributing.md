# Contributing to Norm

Any contributions are welcome, be it pull requests, code reviews, documentation improvements, bug reports, or feature requests.


## Contributing through Code

-   See the [issues on GitHub](http://github.com/moigagoo/norm/issues).

-   Run the tests before and after you change the code.

    The recommended way to run the tests is via [Docker](https://www.docker.com/) and [Docker Compose](https://docs.docker.com/compose/):

        $ docker-compose run --rm tests                     # run all test suites
        $ docker-compose run --rm test tests/tpostgres.nim  # run a single test suite

    If you don't mind running two PostgreSQL servers on `postgres_1` and `postgres_2`, feel free to run the test suites natively:

        $ nimble test

    Note that you only need the PostgreSQL servers to run the PostgreSQL backend tests, so:

        $ nim c -r tests/tsqlite.nim    # doesn't require PostgreSQL servers, but requires SQLite
        $ nim c -r tests/tobjutils.nim  # doesn't require anything at all

-   Use camelCase instead of snake_case.

-   New procs must have a documentation comment. If you modify an existing proc, update the comment.


## Contributing through Docs

Norm docs are shipped with Norm in `docs` directory.

The docs are writtem in Markdown and built with [Folaint](https://foliant.rocks) using [MkDocs](https://mkdocs.org) as backend.

To build the docs site locally, use Docker Compose:

    $ docker-compose -p norm -f docs/docker-compose.yml run --rm docs make site

The generated site is be placed in `docs/norm-docs.mkdocs`.
