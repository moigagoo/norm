#########
Changelog
#########


=====
1.0.0
=====

-   Initial release.


=====
1.0.1
=====

-   Respect custom field parsers and formatters.
-   Type conversion: Fix issue with incorrect conversion of field named ``name``.
-   Rowutils: Respect ``ro`` pragma in ``toRow`` proc.
-   Objutils: Respect ``ro`` pragma in ``fieldNames`` proc.


=====
1.0.2
=====

-   Procs defined in ``db`` macro are now passed as is to the resulting code and are not forced inside ``withDb`` template.
-   Allow to override column names for fields with ``dbCol`` pragma.


=====
1.0.3
=====

-   Objutils: Rename ``[]`` field accessor to ``dot`` to avoid collisions with ``tables`` module.


=====
1.0.4
=====

-   Add ``WHERE`` lookup to ``getMany`` procs.


=====
1.0.5
=====

-   Do not require ``chronicles`` package.
