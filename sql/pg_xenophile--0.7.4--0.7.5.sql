-- Complain if script is sourced in `psql`, rather than via `CREATE EXTENSION`.
\echo Use "CREATE EXTENSION pg_xenophile" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

-- Remove incorrect description of `pg_dump`/`pg_restore` behavior with `regclass` columns.
comment on table l10n_table is
$md$The `l10n_table` table is meant to keep track and manage all the `_l10n`-suffixed tables.

By inserting a row in this table, with just the
details of the base table, a many-to-one l10n table called
`<base_table_name>_l10n` will be created by the `maintain_l10n_objects`
trigger.  This trigger will also take care of creating the
`<base_table_name>_l10n_<base_lang_code>` view as well as one such view for
all the `target_lang_codes`.  These views combine the columns of the base
table with the columns of the l10n table, filtered by the language code
specific to that particular view.

One of the reasons to manage this through a table rather than through a stored
procedure is that a list of such enhanced l10n tables needs to be kept by
`pg_xenophile` anyway: in the likely case that updates necessitate the
upgrading of (the views and/or triggers around) these tables, the extension
update script will know where to find everything.
$md$;

-- New comment.
comment on column l10n_table.base_table_regclass is
$md$The OID of the base table.

Because [`regclass`](https://www.postgresql.org/docs/current/datatype-oid.html)
is used for this column's type, rather than the ‘raw’ `oid` type, its `text`
representation dumped by `pg_dump` will be the (schema-qualified) table name
rather than the OID number.

That the canonical string representation of `regclass` guarantees
`pg_dump`/`pg_restore` consistency is verified by the `make test_dump_restore`
target.
$md$;

-- New comment.
comment on column l10n_table.l10n_table_regclass is
$md$The OID of the l10n table.

Because [`regclass`](https://www.postgresql.org/docs/current/datatype-oid.html)
is used for this column's type, rather than the ‘raw’ `oid` type, its `text`
representation dumped by `pg_dump` will be the (schema-qualified) table name
rather than the OID number.

That the canonical string representation of `regclass` guarantees
`pg_dump`/`pg_restore` consistency is verified by the `make test_dump_restore`
target.
$md$;

--------------------------------------------------------------------------------------------------------------

comment on procedure create_l10n_view is
$md$Create a language code-suffixed view for a given translated table.

The reason that `create_l10n_view()` is a separate routine and not part of the
`l10n_table__maintain_l10n_objects()` trigger function is that you may have a
requirement to _not_ make l10n views for each of a l10n table's target
languages and instead prefer to create temporary views on an as-needed basis
(by passing the `temp$ => true` parameter).
$md$;

--------------------------------------------------------------------------------------------------------------

comment on function l10n_table_with_fresh_ddl(l10n_table) is
$md$Return the given `l10n_table` record, refreshed with data from the current schema.
$md$;

--------------------------------------------------------------------------------------------------------------
