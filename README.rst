###############
Norm, a Nim ORM
###############

**Norm** is an ORM that doesn't try to outsmart you. While lubricating the boring parts of working with DB, it doesn't try to solve complex problems best solved by humans.

To use Norm, you need to learn just a few concepts:

- wrap a ``type`` section in a ``db`` block to define DB model
- add pragmas to finetune the model
- create tables with ``createTables``
- query the DB in ``withDb`` blocks with predefined CRUD procs

Norm supports SQLite and PostgreSQL.

`Read the API docs → <https://moigagoo.github.io/norm/norm.html>`__
