-- Complain if script is sourced in psql, rather than via `CREATE EXTENSION`
\echo Use "CREATE EXTENSION pg_xenophile" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

alter table l10n_table
    add check (
        (l10n_table_belongs_to_extension_name is null) = (l10n_table_belongs_to_extension_version is null)
    );

--------------------------------------------------------------------------------------------------------------

-- New comment.
comment on column country.country_belongs_to_pg_xenophile is
$md$`pg_dump` will ignore rows for which this is `true`.

Make sure that this column is `false` when you add your own country.  When your
country is an official country according to the ISO standard, please make sure
that it will be included upstream in `pg_xenophile`, so that all users of the
extension can profit from up-to-date information.
$md$;

--------------------------------------------------------------------------------------------------------------

-- New comment.
comment on column country_postal_code_pattern.postal_code_pattern_belongs_to_pg_xenophile is
$md$Whether or not this pattern was shipped with the `pg_xenophile` extension.

Make sure that, for your custom additions to this table, this column is
`false`.  Even better, though: contribute new or updated postal code patterns
upstream, to `pg_xenophile`, so that everybody may profit from your knowledge.

Please note, that you will run into problems with dump/restore when you add
records to this table from within your own dependent extension set up scripts.
$md$;

--------------------------------------------------------------------------------------------------------------

comment on column lang.lang_belongs_to_pg_xenophile is
$md$`pg_dump` will ignore rows for which this is `true`.

Make sure that this column is `false` when you add your own language.  When
your language is an official language according to the ISO standard, please
make sure that it will be included upstream in `pg_xenophile`, so that all
users of the extension can profit from up-to-date information.

Please note, that you will run into problems with dump/restore when you add
records to this table from within your own dependent extension set up scripts.
$md$;

--------------------------------------------------------------------------------------------------------------

-- `lang` was still missing from the list of tables that are (partially) dumped by `pg_dump`.
select pg_catalog.pg_extension_config_dump('lang' ,'WHERE NOT lang_belongs_to_pg_xenophile');

--------------------------------------------------------------------------------------------------------------

-- Update comment.
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
    `l10n_table_belongs_to_extension_name IS NULL` are included in the dump.
2.  OIDs of tables and other catalog objects are not guaranteed to remain the
    same between `pg_dump` and `pg_restore`.
$md$;
-- TODO: Correct explanation of `pg_dump` OID behaviour

--------------------------------------------------------------------------------------------------------------

-- Adjust to correct column name and type.
select pg_catalog.pg_extension_config_dump(
    'l10n_table'
    ,'WHERE l10n_table_belongs_to_extension_name IS NULL'
);

--------------------------------------------------------------------------------------------------------------

-- Add missing procedure-local settings.
alter procedure test__l10n_table
    set client_min_messages to 'WARNING'
    set plpgsql.check_asserts to true;

--------------------------------------------------------------------------------------------------------------
