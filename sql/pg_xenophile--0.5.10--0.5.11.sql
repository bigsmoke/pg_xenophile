-- Complain if script is sourced in psql, rather than via `CREATE EXTENSION`
\echo Use "CREATE EXTENSION pg_xenophile" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

-- Put entire summary on first line.
-- Add second reason for also keeping track of the table names and not just the `regclass`es.
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
procedure is that a list of such enhance l10n tables needs to be kept by
`pg_xenophile` anyway: in the likely case that updates necessitate the
upgrading of (the views and/or triggers around) these tables, the extension
update script will know where to find everything.

It may not immediately be obvious why, besides the `base_table_regclass` and
the `l10n_table_regclass` columns, `schema_name`, `base_table_name` and
`l10n_table_name` also exist.  After all, PostgreSQL has some very comfortable
magic surrounding `regclass` and related [object identifier
types](https://www.postgresql.org/docs/current/datatype-oid.html).  Two reasons:

1.  Even though `pg_dump` has the ability to dump OIDs, tables belonging
    to extensions are not dumped at all, except for any part exempted from this
    using the `pg_catalog.pg_extension_config_dump()` function.  For
    `l10n_table`, only the columns for which
    `l10n_table_belongs_to_pg_xenophile = false` are included in the dump.
2.  OIDs of tables and other catalog objects are not guaranteed to remain the
    same between `pg_dump` and `pg_restore`.
$md$;

--------------------------------------------------------------------------------------------------------------
