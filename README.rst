###############
Norm, a Nim ORM
###############

Norm is an ORM for Nim that doesn't try to outsmart you. It lubricates the boring parts of working
with DB but won't try to solve complex problems that are best solved by humans anyway.

To use Norm, you need to learn just a few concepts:

- to define DB models, wrap a type section with objects in a ``db`` block
- to finetune the model, add pragmas to objects and fields
- to work with the DB, use ``withDB`` block
- for CRUD, use the predefined ``insert``, ``getOne``, ``getMany``, ``update``,
and ``delete`` procs
- to create tables, call ``createTables``, to drop tables call ``dropTables``

`Read the API docs → <https://moigagoo.github.io/norm/norm.html>`__
