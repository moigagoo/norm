##########
Quickstart
##########

============
Installation
============

Install Norm with nimble::

    $ nimble install norm

And add Norm to your .nimble file::

    requires "nim >= 1.0.0", "norm"


================
Your First Model
================

1.  Start by describing your app's objects in a regular type section. Create a file called ``models.nim`` with this this content::

        type
          Person = object
            email: string
            age: Natural

2.  Then, to map this definition to an actual DB, wrap the type section in ``db`` macro, imported from ``norm/sqlite`` or ``norm/postgres``::

        import norm/sqlite

        db("app.db", "", "", ""):
          type
            Person = object
              email: string
              age: Natural

    ``db`` macro signature follows the signature of ``open`` procs from Nim stdlib's ``db_*`` modules.

3.  Create the tables with ``createTables``::

        withDb:
          createTables()
