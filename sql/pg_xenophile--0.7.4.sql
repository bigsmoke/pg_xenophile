-- Complain if script is sourced in `psql`, rather than via `CREATE EXTENSION`.
\echo Use "CREATE EXTENSION pg_xenophile" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

comment on extension pg_xenophile is $markdown$
# `pg_xenophile` PostgreSQL extension

[![PGXN version](https://badge.fury.io/pg/pg_xenophile.svg)](https://badge.fury.io/pg/pg_xenophile)

The `pg_xenophile` PostgreSQL extension bundles a bunch of data, data
structures and routines that you often end up needing when working on an
international project:

- tables with the usual data that you need on countries, regions, languages
  and currencies;
- functions to easily store and access translated strings; and
- (trigger) functions to set up one-to-many translation tables with easy-to-use
  views on top.

It's perfectly valid to _just_ use `pg_xenophile` as a repository for
up-to-date lists of countries and languages and such.  But, the extension
becomes especially worthwhile if you want some comfort on top of the common
many-to-one translation-table pattern.

> All your ethnocentrism are belong to us.

## Using `pg_xenophile`

To use the list of countries (from the [`country` table](#table-country)) or
languages (from the [`lang` table](#table-lang), just use them.  And don't be
afraid of using the natural keys in your foreign keys!  If you've been told to
fear them, you will soon be attached to the convenience of not needing to join
to know what a foreign key value means.

If you want a translatable table, you have to register the base table with the
[`l10n_table` meta table](#table-l10n_table).  See the [`l10n_table`
documentation](#table-l10n_table) in the reference for details.  From the
`l10n_table` documentation, you should also be able to learn how to work with
the `lang_l10n`, `lang_l10n_en`, `country_l10n` and `country_l10n_en` tables
and views that are manintained via the triggers on this meta table.

## Extension-specific settings

| Extenion-hooked setting name     | `app.`-hooked setting name             | Default setting value           |
| -------------------------------- | -------------------------------------- | ------------------------------- |
| `pg_xenophile.base_lang_code`    | `app.settings.i18n.base_lang_code`     | `'en'::xeno.lang_code_alpha2`   |
| `pg_xenophile.user_lang_code`    | `app.settings.i18n.user_lang_code`     | `'en'::xeno.lang_code_alpha2`   |
| `pg_xenophile.target_lang_codes` | `app.settings.i18n.target_lang_codes`  | `'{}'::xeno.lang_code_alpha2[]` |

The reason that each `pg_xenophile` setting has an equivalent setting with an
`app.settings.i18n` prefix is because the powerful PostgREST can pass on such
settings from environment variables: `PGRST_APP_SETTINGS_*` maps to
`app.settings.*`.  The `app.settings.`-prefixed settings take precedence over
`pg_xenophile.`-prefixed settings.

Supporting _only_ the `app.settings.`-prefixed settings would not be a good
idea, because, in the circumstance that you would be running an extension
called “`app`”, these settings might disappear, as per the [relevant
documentation](https://www.postgresql.org/docs/15/runtime-config-custom.html):

> […]  Such variables are treated as placeholders and have no function until
> the module that defines them is loaded. When an extension module is loaded, it
> will add its variable definitions and convert any placeholder values according
> to those definitions. If there are any unrecognized placeholders that begin
> with its extension name, warnings are issued and those placeholders are
> removed.

In addition to the above, the `user_lang_code` setting, if set as neither
`app.settings.i18n.user_lang_code` and `pg_xenophile.user_lang_code`, falls
back to the first two letters of the `lc_messages` setting.

### Internal settings

| Setting name                                 | Default setting value           |
| -------------------------------------------- | ------------------------------- |
| `pg_xenophile.in_l10n_table_event_trigger`   | `false`                         |
| `pg_xenophile.in_l10n_table_row_trigger`     | `false`                         |
| `pg_xenophile.pg_restore_seems_active`       | `false`                         |

<?pg-readme-reference?>

## Missing/planned/possible features

* Currently (as of version 0.7.4), only ISO 639-1 (2-letter) language codes are
  supported.  It would be nice if at least ISO 639-2 3-letter code would be
  supported, and possibly ISO 639-2/T and 639-2/B as well.  Even better would be
  if [BPC 47 / RFC 5646](https://datatracker.ietf.org/doc/html/rfc5646) was
  supported.  If I (Rowan) do change the primary language identification method,
  I will try to do so _before_ `pg_xenophile` 1.0 is released, because
  introducing breaking changes post-1.0 is assholish towards the couple of users
  that might by then already depend on this extension.

## Extension authors and contributors

* [Rowan](https://www.bigsmoke.us/) originated this extension in 2022 while
  developing the PostgreSQL backend for the [FlashMQ SaaS MQTT cloud
  broker](https://www.flashmq.com/).  Rowan does not like to see himself as a
  tech person or a tech writer, but, much to his chagrin, [he
  _is_](https://blog.bigsmoke.us/category/technology). Some of his chagrin
  about his disdain for the IT industry he poured into a book: [_Why
  Programming Still Sucks_](https://www.whyprogrammingstillsucks.com/).  Much
  more than a “tech bro”, he identifies as a garden gnome, fairy and ork rolled
  into one, and his passion is really to [regreen and reenchant his
  environment](https://sapienshabitat.com/).  One of his proudest achievements
  is to be the third generation ecological gardener to grow the wild garden
  around his beautiful [family holiday home in the forest of Norg, Drenthe,
  the Netherlands](https://www.schuilplaats-norg.nl/) (available for rent!).

<?pg-readme-colophon?>

$markdown$;

--------------------------------------------------------------------------------------------------------------

comment on schema xeno is
$md$The `xeno` schema belongs to the `pg_xenophile` extension.

Postgres (as of Pg 15) doesn't allow one to specify a _default_ schema, and do
something like `schema = 'xeno'` combined with `relocatable = true` in the
`.control` file.  Therefore I decided to bluntly force the `xeno` schema name
upon you, even though you might have very well (and justifyingly so) preferred
something like `i18n`.
$md$;

--------------------------------------------------------------------------------------------------------------

do $$
begin
    execute 'ALTER DATABASE ' || current_database()
        || ' SET pg_xenophile.readme_url TO '
        || quote_literal('https://github.com/bigsmoke/pg_xenophile/blob/master/README.md');
end;
$$;

--------------------------------------------------------------------------------------------------------------

create or replace function pg_xenophile_readme()
    returns text
    volatile
    set search_path from current
    set pg_readme.include_view_definitions to true
    set pg_readme.include_routine_definitions_like to '{test__%}'
    language plpgsql
    as $plpgsql$
declare
    _readme text;
begin
    create extension if not exists pg_readme;

    _readme := pg_extension_readme('pg_xenophile'::name);

    raise transaction_rollback;  -- to drop extension if we happened to `CREATE EXTENSION` for just this.
exception
    when transaction_rollback then
        return _readme;
end;
$plpgsql$;

comment on function pg_xenophile_readme() is
$md$Generates a README in Markdown format using the amazing power of the `pg_readme` extension.

Temporarily installs `pg_readme` if it is not already installed in the current database.
$md$;

--------------------------------------------------------------------------------------------------------------

create or replace function pg_xenophile_meta_pgxn()
    returns jsonb
    stable
    language sql
    return jsonb_build_object(
        'name'
        ,'pg_xenophile'
        ,'abstract'
        ,'More than the bare necessities for i18n.'
        ,'description'
        ,'The pg_xenophile extension provides more than the bare necessities for working with different'
            ' countries, currencies, languages, and translations.'
        ,'version'
        ,(
            select
                pg_extension.extversion
            from
                pg_catalog.pg_extension
            where
                pg_extension.extname = 'pg_xenophile'
        )
        ,'maintainer'
        ,array[
            'Rowan Rodrik van der Molen <rowan@bigsmoke.us>'
        ]
        ,'license'
        ,'postgresql'
        ,'prereqs'
        ,'{
            "runtime": {
                "requires": {
                    "hstore": 0
                }
            },
            "test": {
                "requires": {
                    "pgtap": 0
                }
            }
        }'::jsonb
        ,'provides'
        ,('{
            "pg_xenophile": {
                "file": "pg_xenophile--0.7.4.sql",
                "version": "' || (
                    select
                        pg_extension.extversion
                    from
                        pg_catalog.pg_extension
                    where
                        pg_extension.extname = 'pg_xenophile'
                ) || '",
                "docfile": "README.md"
            }
        }')::jsonb
        ,'resources'
        ,'{
            "homepage": "https://blog.bigsmoke.us/tag/pg_xenophile",
            "bugtracker": {
                "web": "https://github.com/bigsmoke/pg_xenophile/issues"
            },
            "repository": {
                "url": "https://github.com/bigsmoke/pg_xenophile.git",
                "web": "https://github.com/bigsmoke/pg_xenophile",
                "type": "git"
            }
        }'::jsonb
        ,'meta-spec'
        ,'{
            "version": "1.0.0",
            "url": "https://pgxn.org/spec/"
        }'::jsonb
        ,'generated_by'
        ,'`select pg_xenophile_meta_pgxn()`'
        ,'tags'
        ,array[
            'function',
            'functions',
            'i18n',
            'l10n',
            'plpgsql',
            'table'
        ]
    );

comment on function pg_xenophile_meta_pgxn() is
$md$Returns the JSON meta data that has to go into the `META.json` file needed for PGXN—PostgreSQL Extension Network—packages.

The `Makefile` includes a recipe to allow the developer to: `make META.json` to
refresh the meta file with the function's current output, including the
`default_version`.

And indeed, `pg_xenophile` can be found on PGXN:
https://pgxn.org/dist/pg_xenophile/
$md$;

--------------------------------------------------------------------------------------------------------------

create function fkey_guard(
        foreign_table$ regclass
        ,fkey_column$ name
        ,fkey_value$ anyelement
    )
    returns anyelement
    stable
    parallel safe
    returns null on null input
    not leakproof
    language plpgsql
    as $$
declare
    _foreign_value_exists bool;
begin
    execute 'SELECT EXISTS(SELECT FROM ' || foreign_table$::name || ' WHERE ' || fkey_column$ || ' = $1'
        using $3
        into _foreign_value_exists;

    if not _foreign_value_exists then
        raise foreign_key_violation
            using message = format(
                '%s = %s doesn''t exist in',
                quote_ident(fkey_column$),
                quote_literal(fkey_value$),
                quote_ident(foreign_table$)
            );
    end if;

    return fkey_value$;
end;
$$;

--------------------------------------------------------------------------------------------------------------

create function set_installed_extension_version_from_name()
    returns trigger
    set search_path from current
    language plpgsql
    as $$
declare
    _extension_name_column name;
    _extension_version_column name;
    _extension_name name;
    _extension_version text;
begin
    assert tg_when = 'BEFORE';
    assert tg_op in ('INSERT', 'UPDATE');
    assert tg_level = 'ROW';
    assert tg_nargs = 2;

    _extension_name_column := tg_argv[0];
    _extension_version_column := tg_argv[1];

    execute format('SELECT $1.%I, $1.%I', _extension_name_column, _extension_version_column)
        using NEW
        into _extension_name, _extension_version
    ;

    if _extension_name is null then
        raise null_value_not_allowed using
            message = format(
                'Unexpected %I.%I.%I IS NULL'
                ,tg_table_schema
                ,tg_table_name
                ,_extension_name_column
            )
            ,hint = 'Try adding a `WHEN (%I IS NOT NULL)` condition to the trigger.'
            ,schema = tg_table_schema
            ,table = tg_table_name
            ,column = _extension_name_column
        ;
    end if;

    _extension_version := (select extversion from pg_catalog.pg_extension where extname = _extension_name);

    if _extension_version is null then
        raise no_data_found using
            message = format(
                'Could not find extension %s referenced in %I.%I.%I'
                ,_extension_name
                ,tg_table_schema
                ,tg_table_name
                ,_extension_name_column
            )
            ,schema = tg_table_schema
            ,table = tg_table_name
            ,column = _extension_name_column
        ;
    end if;

    NEW := NEW #= hstore(_extension_version_column::text, _extension_version);

    return NEW;
end;
$$;

comment on function set_installed_extension_version_from_name() is
$md$Sets the installed extension version string in the column named in the second argument for the extension named in the second argument.

See the [`test__set_installed_extension_version_from_name()` test
procedure](#procedure-test__set_installed_extension_version_from_name) for a
working example of this trigger function.

This function was lifted from the `pg_utility_trigger_functions` extension
version. 1.4.0, by means of copy-paste to keep the number of inter-extension
dependencies to a minimum.
$md$;

--------------------------------------------------------------------------------------------------------------

create domain currency_code
    as text
    check (value ~ '^[A-Z]{3}$');

comment on domain currency_code is
$md$Using this domain instead of its underlying `text` type ensures that only uppercase, 3-letter currency codes are allowed.  It does _not_ enforce that the `currency_code` exists in the `currency` table.
$md$;

--------------------------------------------------------------------------------------------------------------

create table currency (
    currency_code currency_code
        primary key
    ,currency_code_num text
        not null
        unique
        check (currency_code_num ~ '^[0-9]{3}$')
    ,currency_symbol text
        not null
        constraint check_currency_symbol_is_1_char
            check (length(currency_symbol) = 1)
    ,decimal_digits int
        not null
        default 2
    ,currency_belongs_to_pg_xenophile boolean
        not null
        default false
);

comment on table currency is
$md$The `currency` table contains the currencies known to `pg_xenophile`.
$md$;

comment on column currency.currency_code is
$md$`currency_code` is a 3-letter ISO 4217 currency code.
$md$;

comment on column currency.currency_code_num is
$md$`currency_code` is the numeric 3-digit ISO 4217 currency code.
$md$;

comment on column currency.currency_belongs_to_pg_xenophile is
$md$Does this currency belong to the `pg_xenophile` extension or not.

If `NOT currency_belongs_to_pg_xenophile`, it is considered a custom currency
inserted by the extension user rather than the extension developer.  Instead
(or in addition) of adding such custom rows, please feel free to submit patches
with all the currencies that you wish for `pg_xenophile` to embrace.
$md$;

select pg_catalog.pg_extension_config_dump(
    'currency',
    'WHERE NOT currency_belongs_to_pg_xenophile'
);

insert into currency
    (currency_code, currency_code_num, currency_symbol, currency_belongs_to_pg_xenophile)
values
    ('EUR', '978', '€', true),
    ('GBP', '826', '£', true),
    ('USD', '840', '$', true)
;

--------------------------------------------------------------------------------------------------------------

create domain country_code_alpha2
    as text
    check (value ~ '^[A-Z]{2}$');

comment on domain country_code_alpha2 is
$md$Using this domain instead of its underlying `text` type ensures that only 2-letter, uppercase country codes are allowed.
$md$;

--------------------------------------------------------------------------------------------------------------

create table country (
    country_code country_code_alpha2
        primary key
    ,country_code_alpha3 text
        unique
        check (country_code_alpha3 ~ '^[A-Z]{3}$')
    ,country_code_num text
        not null
        check (country_code_num ~ '^[0-9]{3}$')
    ,calling_code int
        not null
    ,currency_code text
        not null
        references currency(currency_code)
            on delete restrict
            on update cascade
        default 'EUR'
    ,country_belongs_to_pg_xenophile boolean
        not null
        default false
);

comment on table country is
$md$The ISO 3166-1 alpha-2, alpha3 and numeric country codes, as well as some auxillary information.
$md$;

comment on column country.country_belongs_to_pg_xenophile is
$md$`pg_dump` will ignore rows for which this is `true`.

Make sure that this column is `false` when you add your own country.  When your
country is an official country according to the ISO standard, please make sure
that it will be included upstream in `pg_xenophile`, so that all users of the
extension can profit from up-to-date information.

Please note, that you will run into problems with dump/restore when you add
records to this table from within your own dependent extension set up scripts.
$md$;

select pg_catalog.pg_extension_config_dump(
    'country',
    'WHERE NOT country_belongs_to_pg_xenophile'
);

--------------------------------------------------------------------------------------------------------------

create table country_postal_code_pattern (
    country_code country_code_alpha2
        primary key
        references country(country_code)
    ,valid_postal_code_regexp text
        not null
    ,clean_postal_code_regexp text
    ,clean_postal_code_replace text
    ,postal_code_example text
        not null
    ,postal_code_pattern_checked_on date
    ,postal_code_pattern_information_source text
    ,postal_code_pattern_belongs_to_pg_xenophile bool
        not null
        default false
);

comment on column country_postal_code_pattern.postal_code_pattern_belongs_to_pg_xenophile is
$md$Whether or not this pattern was shipped with the `pg_xenophile` extension.

Make sure that, for your custom additions to this table, this column is
`false`.  Even better, though: contribute new or updated postal code patterns
upstream, to `pg_xenophile`, so that everybody may profit from your knowledge.

Please note, that you will run into problems with dump/restore when you add
records to this table from within your own dependent extension set up scripts.
$md$;

select pg_catalog.pg_extension_config_dump(
    'country_postal_code_pattern',
    'WHERE NOT postal_code_pattern_belongs_to_pg_xenophile'
);

--------------------------------------------------------------------------------------------------------------

create table eu_country (
    country_code country_code_alpha2
        primary key
        references country(country_code)
    ,eu_membership_checked_on date
    ,eu_country_belongs_to_pg_xenophile boolean
        not null
        default false
);

--------------------------------------------------------------------------------------------------------------

create domain lang_code_alpha2
    as text
    check (value ~ '^[a-z]{2}$');


comment on domain lang_code_alpha2 is
$md$ISO 639-1 two-letter (lowercase) language code.
$md$;

--------------------------------------------------------------------------------------------------------------

create domain lang_code_alhpa3
    as text
    check (value ~ '^[a-z]{3}$');

comment on domain lang_code_alhpa3 is
$md$ISO 639-2/T, ISO 639-2/B, or ISO 639-3 (lowercase) language code.
$md$;

--------------------------------------------------------------------------------------------------------------

create table lang (
    lang_code lang_code_alpha2
        primary key
    ,lang_belongs_to_pg_xenophile boolean
        not null
        default false
);

comment on column lang.lang_code is
$md$ISO 639-1 two-letter (lowercase) language code.
$md$;

comment on column lang.lang_belongs_to_pg_xenophile is
$md$`pg_dump` will ignore rows for which this is `true`.

Make sure that this column is `false` when you add your own language.  When
your language is an official language according to the ISO standard, please
make sure that it will be included upstream in `pg_xenophile`, so that all
users of the extension can profit from up-to-date information.

Please note, that you will run into problems with dump/restore when you add
records to this table from within your own dependent extension set up scripts.
$md$;


select pg_catalog.pg_extension_config_dump('lang' ,'WHERE NOT lang_belongs_to_pg_xenophile');

--------------------------------------------------------------------------------------------------------------

create function pg_xenophile_base_lang_code()
    returns lang_code_alpha2
    stable
    leakproof
    set pg_readme.include_this_routine_definition to true
    set search_path from current
    language sql
    return coalesce(
        pg_catalog.current_setting('app.settings.i18n.base_lang_code', true),
        pg_catalog.current_setting('pg_xenophile.base_lang_code', true),
        'en'::text
    )::xeno.lang_code_alpha2;

--------------------------------------------------------------------------------------------------------------

create function pg_xenophile_target_lang_codes()
    returns lang_code_alpha2[]
    stable
    leakproof
    set pg_readme.include_this_routine_definition to true
    set search_path from current
    language sql
    return coalesce(
        pg_catalog.current_setting('app.settings.i18n.target_lang_codes', true),
        pg_catalog.current_setting('pg_xenophile.target_lang_codes', true),
        '{}'::text
    )::xeno.lang_code_alpha2[];

--------------------------------------------------------------------------------------------------------------

create function pg_xenophile_user_lang_code()
    returns lang_code_alpha2
    stable
    leakproof
    set pg_readme.include_this_routine_definition to true
    set search_path from current
    language sql
    return coalesce(
        pg_catalog.current_setting('app.settings.i18n.user_lang_code', true),
        pg_catalog.current_setting('pg_xenophile.user_lang_code', true),
        regexp_replace(pg_catalog.current_setting('lc_messages'), '^([a-z]{2}).*$', '\1'),
        'en'::text
    )::xeno.lang_code_alpha2;

--------------------------------------------------------------------------------------------------------------

create table l10n_table (
    schema_name name
        not null
        default current_schema
    ,base_table_name name
        not null
    ,base_table_regclass regclass
        primary key
    ,base_column_definitions text[]
        not null
    ,l10n_table_name name
        not null
    ,l10n_table_regclass regclass
        not null
        unique
    ,l10n_column_definitions text[]
        not null
    ,l10n_table_constraint_definitions text[]
        not null
        default array[]::text[]
    ,base_lang_code lang_code_alpha2
        not null
        default pg_xenophile_base_lang_code()
    ,target_lang_codes lang_code_alpha2[]
        not null
        default pg_xenophile_target_lang_codes()
    ,l10n_table_belongs_to_extension_name name
    ,l10n_table_belongs_to_extension_version text
    ,check (
        (l10n_table_belongs_to_extension_name is null) = (l10n_table_belongs_to_extension_version is null)
    )
);

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

comment on column l10n_table.l10n_table_belongs_to_extension_name is
$md$This column must be `NOT NULL` if the l10n table is created through extension setup scripts and its row in the meta table must thus be omitted from `pg_dump`.

If `l10n_table_belongs_to_extension_name IS NOT NULL`, then the created
localization (l10n) _table_ will be managed (and thus recreated during a
restore) by the named extension's setup/upgrade script.  That is _not_ the same
as saying that the l10n table's _rows_ will belong to `pg_xenophile`.  To
determine the latter, a `l10n_columns_belong_to_extension_name` column will be
added to the l10n table if the `l10n_table__maintain_l10n_objects()` trigger
function finds `l10n_table_belongs_to_extension_name IS NOT NULL` on insert.

Only developers of this or dependent extensions need to worry about these
booleans.  For users, the default of `false` assures that they will lose none
of their precious data.
$md$;

select pg_catalog.pg_extension_config_dump(
    'l10n_table',
    'WHERE l10n_table_belongs_to_extension_name IS NULL'
);

--------------------------------------------------------------------------------------------------------------

create trigger set_installed_extension_version_from_name
    before insert on l10n_table
    for each row
    when (NEW.l10n_table_belongs_to_extension_name is not null)
    execute function set_installed_extension_version_from_name(
        'l10n_table_belongs_to_extension_name'
        ,'l10n_table_belongs_to_extension_version'
    );

--------------------------------------------------------------------------------------------------------------

create function updatable_l10n_view()
    returns trigger
    set search_path from current
    language plpgsql
    as $$
declare
    _schema_name name;
    _base_table name;
    _l10n_table name;
    _base_columns name[];
    _base_columns_for_upsert name[];
    _l10n_columns name[];
    _base_table_path text;
    _l10n_table_path text;
    _pk_column name;
    _new_base_row record;
    _new_l10n_row record;
    _target_lang_code lang_code_alpha2;
    _generated_pk_is_overriden_by_insert bool := false;
begin
    assert tg_when = 'INSTEAD OF';
    assert tg_level = 'ROW';
    assert tg_op in ('INSERT', 'UPDATE', 'DELETE');
    assert tg_table_name ~ '_l10n_[a-z]{2}$';
    assert tg_nargs = 4;

    -- Unlike other arrays in Pg, `TG_ARGV[]` subscripts start at zero.
    _schema_name := tg_argv[0];
    _base_table := tg_argv[1];
    _l10n_table := tg_argv[2];
    _pk_column := tg_argv[3];
    _base_table_path := quote_ident(_schema_name) || '.' || quote_ident(_base_table);
    _l10n_table_path := quote_ident(_schema_name) || '.' || quote_ident(_l10n_table);
    _target_lang_code := right(tg_table_name, 2);
    _base_columns := array(
        select  columns.column_name
        from    information_schema.columns
        where   columns.table_schema = _schema_name
                and columns.table_name = _base_table
    );
    _base_columns_for_upsert := array(
        select  columns.column_name
        from    information_schema.columns
        where   columns.table_schema = _schema_name
                and columns.table_name = _base_table
                and columns.is_generated = 'NEVER'
                and columns.is_identity = 'NO'
    );
    if tg_op = 'INSERT' and not _pk_column = any (_base_columns_for_upsert) then
        execute 'SELECT $1.' || quote_ident(_pk_column) || ' IS NOT NULL'
            using NEW
            into _generated_pk_is_overriden_by_insert;
        if _generated_pk_is_overriden_by_insert then
            -- We append the PK if it is NOT NULL, to make this crash instead of silently
            -- ignoring an explicit PK that should have probably been omitted in the context
            -- the INSERTed into this view.
            _base_columns_for_upsert := _base_columns_for_upsert || _pk_column;
        end if;
    end if;
    _l10n_columns := array(
        select  columns.column_name
        from    information_schema.columns
        where   columns.table_schema = _schema_name
                and columns.table_name = _l10n_table
                and columns.column_name != 'l10n_lang_code'
    );

    --
    -- We start with INSERT, UPDATE or DELETE on the base table.
    --

    if tg_op = 'INSERT' then

        execute 'INSERT INTO ' || _base_table_path || '('
                || (
                        select string_agg(quote_ident(col), ', ')
                        from unnest(_base_columns_for_upsert) as col
                    )
                || ') VALUES ('
                || (
                        select string_agg('$1.' || quote_ident(col), ', ')
                        from unnest(_base_columns_for_upsert) as col
                    )
                || ') RETURNING *'
            using NEW
            into _new_base_row;

        NEW := NEW #= hstore(
            array(
                select  array[key, value]
                from    each(hstore(_new_base_row.*))
                where   value is not null
            )
        );
    elsif tg_op = 'UPDATE' then
        execute 'UPDATE ' || _base_table_path || '
                SET
                ' || (
                        select string_agg(quote_ident(col) || ' = $1.' || quote_ident(col), ', ')
                        from unnest(_base_columns_for_upsert) as col
                ) || '
                WHERE ' || quote_ident(_pk_column) || ' = $2.' || quote_ident(_pk_column)
                || ' RETURNING *'
            using NEW, OLD
            into _new_base_row;

        NEW := NEW #= hstore(
            array(
                select  array[key, value]
                from    each(hstore(_new_base_row.*))
                where   value is not null
            )
        );
    elsif tg_op = 'DELETE' then
        execute 'DELETE FROM ' || _base_table_path || ' WHERE '
                || quote_ident(_pk_column) || ' = $1.' || quote_ident(_pk_column)
            using OLD;
        -- The `ON DELETE CASCADE` on the FK from the l10n table will do the rest.
    end if;

    --
    -- After INSERT or UPDATE on the base table, we need to also INSERT or UPDATE the l10n table.
    --

    if tg_op = 'INSERT' or (tg_op = 'UPDATE' and OLD.l10n_lang_code is null) then
        execute 'INSERT INTO ' || _l10n_table_path
                || '(l10n_lang_code,'
                || (
                        select string_agg(quote_ident(col), ', ')
                        from unnest(_l10n_columns) as col
                    )
                || ') VALUES ('
                || quote_literal(_target_lang_code) || ','
                || (
                        select string_agg('$1.' || quote_ident(col), ', ')
                        from unnest(_l10n_columns) as col
                    )
                || ') RETURNING *'
            using NEW
            into _new_l10n_row;

        NEW := NEW #= hstore(
            array(
                select  array[key, value]
                from    each(hstore(_new_l10n_row.*))
                where   value is not null
            )
        );
    elsif tg_op = 'UPDATE' then
        execute 'UPDATE ' || _l10n_table_path || '
                SET
                ' || (
                        select string_agg(quote_ident(col) || ' = $1.' || quote_ident(col), ', ')
                        from unnest(_l10n_columns) as col
                ) || '
                WHERE ' || quote_ident(_pk_column) || ' = $2.' || quote_ident(_pk_column)
                    || ' AND l10n_lang_code = ' || quote_literal(_target_lang_code)
                || ' RETURNING *'
            using NEW, OLD
            into _new_l10n_row;

        NEW := NEW #= hstore(
            array(
                select  array[key, value]
                from    each(hstore(_new_l10n_row.*))
                where   value is not null
            )
        );
    end if;

    if tg_op = 'DELETE' then
        return OLD;
    end if;
    return NEW;
end;
$$;

--------------------------------------------------------------------------------------------------------------

create or replace procedure create_l10n_view(
        table_schema$ name
        ,base_table$ name
        ,l10n_table$ name
        ,lang_code$ lang_code_alpha2
        ,temp$ boolean default false
    )
    set search_path from current
    language plpgsql
    as $$
declare
    _fk_details record;
    _view_name name;
    _col_with_default record;
begin
    begin
        select
            tc.table_schema,
            tc.constraint_name,
            tc.table_name,
            kcu.column_name,
            ccu.table_schema as foreign_table_schema,
            ccu.table_name as foreign_table_name,
            ccu.column_name as foreign_column_name
        into strict
            _fk_details
        from
            information_schema.table_constraints as tc
            join information_schema.key_column_usage as kcu
              on tc.constraint_name = kcu.constraint_name
              and tc.table_schema = kcu.table_schema
            join information_schema.constraint_column_usage as ccu
              on ccu.constraint_name = tc.constraint_name
              and ccu.table_schema = tc.table_schema
        where
            tc.constraint_type = 'FOREIGN KEY'
            and tc.table_schema = table_schema$
            and tc.table_name = l10n_table$
            and ccu.table_name = base_table$
            -- Disambiguate the double foreign key to "lang" in "lang_l10n" table:
            and kcu.column_name != 'l10n_lang_code'
        ;
        exception
            when no_data_found then
                raise exception 'No FK to % found in %', base_table$, l10n_table$;
            when too_many_rows then
                raise exception 'More than one FK to % found in %', base_table$, l10n_table$;
    end;

    _view_name := l10n_table$ || '_' || lang_code$;
    execute  'CREATE OR REPLACE' || (case when temp$ then ' TEMPORARY' else '' end)
        || ' VIEW ' || quote_ident(table_schema$) || '.' || quote_ident(_view_name)
        || ' AS SELECT '
        ||  (
                select
                    string_agg(quote_ident(table_name) || '.' || quote_ident(column_name), ', ')
                from
                    (
                        select
                            columns.table_name
                            ,columns.column_name
                        from
                            information_schema.columns
                        where
                            columns.table_schema = table_schema$
                            and (
                                columns.table_name = base_table$
                                or (
                                    columns.table_name = l10n_table$
                                    and columns.column_name != _fk_details.column_name
                                )
                            )
                        order by
                            case when columns.table_name = base_table$ then 0 else 1 end
                            ,columns.ordinal_position
                    ) as which_table_does_not_matter
            )
        || ' FROM '
        || quote_ident(table_schema$) || '.' || quote_ident(base_table$)
        || ' LEFT OUTER JOIN '
        || quote_ident(table_schema$) || '.' || quote_ident(l10n_table$)
        || ' ON ' || quote_ident(base_table$) || '.' || quote_ident(_fk_details.column_name) || ' = '
        || quote_ident(l10n_table$) || '.' || quote_ident(_fk_details.foreign_column_name)
        || ' AND ' || quote_ident(l10n_table$) || '.l10n_lang_code = ' || quote_literal(lang_code$)
    ;

    for _col_with_default in
        select
            columns.column_name
            ,columns.column_default
        from
            information_schema.columns
        where
            columns.table_schema = table_schema$
            and columns.table_name in (base_table$, l10n_table$)
            and columns.column_default is not null
    loop
        execute 'ALTER VIEW ' || quote_ident(table_schema$) || '.' || quote_ident(_view_name)
            || ' ALTER COLUMN ' || quote_ident(_col_with_default.column_name)
            || ' SET DEFAULT ' || _col_with_default.column_default;
    end loop;

    execute 'CREATE TRIGGER updatable_l10n_view'
            || ' INSTEAD OF INSERT OR UPDATE OR DELETE'
            || ' ON ' || quote_ident(table_schema$) || '.' || quote_ident(_view_name)
            || ' FOR EACH ROW EXECUTE FUNCTION updatable_l10n_view('
                || quote_literal(table_schema$)
                || ', ' || quote_literal(base_table$)
                || ', ' || quote_literal(l10n_table$)
                || ', ' || quote_literal(_fk_details.foreign_column_name)
            || ')';
end;
$$;

--------------------------------------------------------------------------------------------------------------

create function l10n_table_with_fresh_ddl(inout l10n_table)
    stable
    set search_path from current
    language plpgsql
    as $$
begin
    $1.base_column_definitions := (
        select
            array_agg(
                pg_attribute.attname
                || ' ' || pg_catalog.format_type(pg_attribute.atttypid, pg_attribute.atttypmod)
                || case when pg_attribute.attnotnull then ' NOT NULL' else '' end
                || case when pg_attrdef.oid is not null
                    then ' DEFAULT ' || pg_catalog.pg_get_expr(pg_attrdef.adbin, pg_attrdef.adrelid, true)
                    else ''
                end
                order by
                    pg_attribute.attnum
            )
        from
            pg_catalog.pg_attribute
        left outer join
            pg_catalog.pg_attrdef
            on pg_attribute.atthasdef
            and pg_attrdef.adrelid = pg_attribute.attrelid
            and pg_attrdef.adnum = pg_attribute.attnum
        where
            pg_attribute.attrelid = ($1).base_table_regclass
            and pg_attribute.attnum >= 1
            and not pg_attribute.attisdropped
    );

    $1.l10n_column_definitions := (
        select
            array_agg(
                pg_attribute.attname
                || ' ' || pg_catalog.format_type(pg_attribute.atttypid, pg_attribute.atttypmod)
                || case when pg_attribute.attnotnull then ' NOT NULL' else '' end
                || case when pg_attrdef.oid is not null
                    then ' DEFAULT ' || pg_catalog.pg_get_expr(pg_attrdef.adbin, pg_attrdef.adrelid, true)
                    else ''
                end
                order by
                    pg_attribute.attnum
            )
        from
            pg_catalog.pg_attribute
        left outer join
            pg_catalog.pg_attrdef
            on pg_attribute.atthasdef
            and pg_attrdef.adrelid = pg_attribute.attrelid
            and pg_attrdef.adnum = pg_attribute.attnum
        where
            pg_attribute.attrelid = ($1).l10n_table_regclass
            and pg_attribute.attnum >= 1
            and not pg_attribute.attisdropped
            and pg_attribute.attname != 'l10n_lang_code'
            and not exists (
                select
                from
                    pg_catalog.pg_constraint
                where
                    pg_constraint.conrelid = pg_attribute.attrelid
                    and pg_constraint.contype = 'p'
                    and pg_attribute.attnum = any (pg_constraint.conkey)
            )
    );

    $1.l10n_table_constraint_definitions := (
        select
            array_agg(
                pg_get_constraintdef(pg_constraint.oid, true)
                order by
                    pg_constraint.contype
                    ,pg_constraint.conname
            )
        from
            pg_catalog.pg_constraint
        where
            pg_constraint.conrelid = ($1).l10n_table_regclass
    );
end;
$$;

--------------------------------------------------------------------------------------------------------------

create or replace function l10n_table__maintain_l10n_objects()
    returns trigger
    set search_path from current
    set pg_xenophile.in_l10n_table_row_trigger to true
    reset client_min_messages
    language plpgsql
    as $$
declare
    _l10n_table_path text;
    _base_table_path text;
    _pk_details record;
    _existing_l10n_views name[];
    _required_l10n_views name[];
    _l10n_views_to_create name[];
    _l10n_views_to_drop name[];
    _missing_view name;
    _extraneous_view name;
    _copying bool;
begin
    -- Generally, triggers that propagate changes to other database objects should be `AFTER` triggers,
    -- no `BEFORE` triggers.  In this case, however, we want to, for example, be able to store the names
    -- and identifiers of the newly created table in the very row that is being inserted.
    assert tg_when = 'BEFORE';
    assert tg_level = 'ROW';
    assert tg_op in ('INSERT', 'UPDATE', 'DELETE');
    assert tg_table_schema = 'xeno';
    assert tg_table_name = 'l10n_table';
    assert tg_nargs = 0;

    -- When we are inside a `COPY` command, it is likely that we're restoring from a `pg_dump`.
    -- Otherwise, why would you want to bulk insert into such a small table?
    _copying := tg_op = 'INSERT' and exists (
        select from
            pg_stat_progress_copy
        where
            relid = tg_relid
            and command = 'COPY FROM'
            and type = 'PIPE'
    );

    if _copying and NEW.l10n_table_belongs_to_extension_name is not null then
        raise exception using
            message = format(
                'Unexpected `%I.%I.l10n_table_belongs_to_extension_name IS NOT NULL` during `COPY`.'
            )
            ,hint = 'Probably, the second parameter to `pg_extension_config_dump()` was faulty.'
            ,schema = tg_table_schema
            ,table = tg_table_name
            ,column = 'l10n_table_belongs_to_extension_name';
    end if;

    if _copying then
        NEW.l10n_table_regclass := (NEW.schema_name || '.' || NEW.l10n_table_name)::regclass;
        NEW.base_table_regclass := (NEW.schema_name || '.' || NEW.base_table_name)::regclass;

        set pg_xenophile.pg_restore_seems_active to true;

        return NEW;
    end if;

    if tg_op = 'INSERT' and NEW.l10n_table_name is not null then
        raise integrity_constraint_violation
            using message = '`l10n_table_name` is not supposed to be provided on `INSERT`, because'
                ' it is supposed to be determined automatically by this trigger `ON INSERT`.';
    end if;
    if tg_op = 'INSERT' and NEW.l10n_table_regclass is not null then
        raise integrity_constraint_violation
            using message = '`l10n_table_regclass` supposed to be `NULL` on `INSERT`, because the'
                ' l10n table is supposed to created by this trigger `ON INSERT`.';
    end if;

    if tg_op in ('INSERT', 'UPDATE') and array_length(NEW.l10n_column_definitions, 1) = 0 then
        raise integrity_constraint_violation
            using message = 'It makes no sense to make an l10n table without any extra columns.'
                ' Specify the columns you want in the `l10n_column_definitions` column.';
    end if;

    if not coalesce(
            nullif(current_setting('pg_xenophile.in_l10n_table_event_trigger', true), ''),
            'false'
        )::bool
        and tg_op = 'UPDATE'
        and (
            NEW.base_column_definitions != OLD.base_column_definitions
            or NEW.l10n_column_definitions != OLD.l10n_column_definitions
            or NEW.l10n_table_constraint_definitions != OLD.l10n_table_constraint_definitions
        )
    then
        raise integrity_constraint_violation
            using message = 'After the initial `INSERT`, column and constraint definitions should not be'
                ' altered manually, only via `ALTER TABLE` statements, that will propagate via the'
                ' `l10n_table__track_alter_table_events` event trigger.';
            -- Feel free to implement support for this if this causes you discomfort.
    end if;

    if tg_op in ('INSERT', 'UPDATE') then
        if NEW.base_table_regclass is null then
            if NEW.schema_name is null then
                raise integrity_constraint_violation
                    using message = 'schema_name must be specified if base_table_regclass is not given.';
            end if;
            if NEW.base_table_name is null then
                raise integrity_constraint_violation
                    using message = 'base_table_name must be specified if base_table_regclass is not given.';
            end if;
            NEW.base_table_regclass := (NEW.schema_name || '.' || NEW.base_table_name)::regclass;
        elsif NEW.base_table_regclass is not null then
            select
                pg_class.relnamespace::regnamespace::name
                ,pg_class.relname
            into
                NEW.schema_name
                ,NEW.base_table_name
            from
                pg_catalog.pg_class
            where
                pg_class.oid = NEW.base_table_regclass
            ;
        end if;
    end if;
    _base_table_path := NEW.base_table_regclass::text;

    NEW.l10n_table_name := NEW.base_table_name || '_l10n';
    _l10n_table_path := quote_ident(NEW.schema_name) || '.' || quote_ident(NEW.l10n_table_name);
    if tg_op = 'INSERT' and to_regclass(_l10n_table_path) is not null then
        raise integrity_constraint_violation
            using message = 'The l10n table is not supposed to exist yet.';
    end if;

    if tg_op = 'INSERT' then
        begin
            select
                kcu.column_name
                ,c.data_type
                ,coalesce(
                    quote_ident(c.domain_schema) || '.' || quote_ident(c.domain_name)
                    ,c.data_type
                ) as data_type_path
            into strict
                _pk_details
            from
                information_schema.table_constraints as tc
                join information_schema.key_column_usage as kcu
                    on tc.constraint_name = kcu.constraint_name
                    and tc.table_schema = kcu.table_schema
                join information_schema.columns as c
                    on kcu.table_schema = c.table_schema
                    and kcu.table_name = c.table_name
                    and kcu.column_name = c.column_name
            where
                tc.constraint_type = 'PRIMARY KEY'
                and tc.table_schema = NEW.schema_name
                and tc.table_name = NEW.base_table_name
            ;
        exception
            when no_data_found then
                raise exception 'No PK found in %', NEW.base_table_name;
            when too_many_rows then
                raise exception 'Multi-column PK found in %; Multi-column PKs not supported',
                    NEW.base_table_name;
        end;

        execute 'CREATE TABLE ' || _l10n_table_path || ' (
                ' || quote_ident(_pk_details.column_name) || ' ' || _pk_details.data_type_path
                || ' REFERENCES ' || _base_table_path || '(' || _pk_details.column_name || ')
                    ON DELETE CASCADE ON UPDATE CASCADE
                ,l10n_lang_code lang_code_alpha2
                    NOT NULL
                    REFERENCES lang(lang_code)
                        ON DELETE RESTRICT
                        ON UPDATE RESTRICT'
                || case when NEW.l10n_table_belongs_to_extension_name is not null then '
                ,l10n_columns_belong_to_extension_name name
                ,l10n_columns_belong_to_extension_version text' else '' end || '
                ,' || array_to_string(NEW.l10n_column_definitions, ', ') || '
                ,PRIMARY KEY (' || quote_ident(_pk_details.column_name) || ', l10n_lang_code)
                ' || array_to_string(NEW.l10n_table_constraint_definitions, ',
                ') || '
            )';

        NEW.l10n_table_regclass := _l10n_table_path::regclass;

        execute 'COMMENT ON TABLE ' || NEW.l10n_table_regclass::text || $ddl$ IS $markdown$
This table is managed by the `pg_xenophile` extension, which has delegated its creation to the `$ddl$ || tg_name || $ddl$` trigger on the `$ddl$ || tg_table_name || $ddl$` table.  To alter this table, just `ALTER` it as you normally would.  The `l10n_table__track_alter_table_events` event trigger will detect such changes, as well as changes to the base table (`$ddl$ || NEW.base_table_name || $ddl$`) referenced by the foreign key (that doubles as primary key) on `$ddl$ || NEW.l10n_table_name || $ddl$`.  When any `ALTER TABLE $ddl$ || quote_ident(NEW.l10n_table_name) || $ddl$` or `ALTER TABLE $ddl$ || quote_ident(NEW.base_table_name) || $ddl$` events are detected, `$ddl$ || tg_table_name || $ddl$`  will be updated—the `base_column_definitions`, `l10n_column_definitions` and `l10n_table_constraint_definitions` columns—with the latest information from the `pg_catalog`.

These changes to `$ddl$ || tg_table_name || $ddl$` in turn trigger the `$ddl$ || tg_name || $ddl$` trigger, which ensures that the language-specific convenience views that (left) join `$ddl$ || NEW.base_table_name || $ddl$` to `$ddl$ || NEW.l10n_table_name || $ddl$` are kept up-to-date with the columns in these tables.

To drop this table, either just `DROP TABLE` it (and the `l10n_table__track_drop_table_events` will take care of the book-keeping or delete its bookkeeping row from `l10n_table`.

$markdown$ $ddl$;

        if NEW.l10n_table_belongs_to_extension_name is not null then
            perform pg_catalog.pg_extension_config_dump(
                _l10n_table_path,
                'WHERE l10n_columns_belong_to_extension_name IS NULL'
            );

            execute 'CREATE TRIGGER set_installed_extension_version_from_name'
                || ' BEFORE INSERT ON ' || NEW.l10n_table_regclass::text
                || ' FOR EACH ROW'
                || ' WHEN (NEW.l10n_columns_belong_to_extension_name IS NOT NULL)'
                || ' EXECUTE FUNCTION set_installed_extension_version_from_name('
                || '''l10n_columns_belong_to_extension_name'', ''l10n_columns_belong_to_extension_version'')';
        end if;

        NEW := l10n_table_with_fresh_ddl(NEW.*);
    end if;

    _existing_l10n_views := (
        select
            coalesce(array_agg(views.table_name), array[]::name[])
        from
            information_schema.views
        where
            views.table_schema = OLD.schema_name
            and views.table_name like OLD.l10n_table_name || '\___'
    );
    raise debug 'Existing l10n views: %', _existing_l10n_views;

    if tg_op in ('INSERT', 'UPDATE') then
        _required_l10n_views := (
            select
                array_agg(distinct NEW.l10n_table_name || '_' || required_lang_code)
            from
                unnest(NEW.base_lang_code || NEW.target_lang_codes) as required_lang_code
        );
    elsif tg_op = 'DELETE' then
        _required_l10n_views := array[]::name[];
    end if;
    raise debug 'Required l10n views: %', _required_l10n_views;

    if tg_op = 'UPDATE'
        and (
            NEW.base_column_definitions != OLD.base_column_definitions
            or NEW.l10n_column_definitions != OLD.l10n_column_definitions
            or NEW.l10n_table_constraint_definitions != OLD.l10n_table_constraint_definitions
        )
    then
        _l10n_views_to_drop := _existing_l10n_views;
        _l10n_views_to_create := _required_l10n_views;
    else
        _l10n_views_to_drop := (
            select
                coalesce(array_agg(lang_code), array[]::lang_code_alpha2[])
            from
                unnest(_existing_l10n_views) as lang_code
            where
                lang_code != all (_required_l10n_views)
        );

        _l10n_views_to_create := (
            select
                coalesce(array_agg(lang_code), array[]::lang_code_alpha2[])
            from
                unnest(_required_l10n_views) as lang_code
            where
                lang_code != all (_existing_l10n_views)
        );
    end if;

    foreach _extraneous_view in array _l10n_views_to_drop
    loop
        execute 'DROP TRIGGER updatable_l10n_view ON '
            || quote_ident(OLD.schema_name) || '.' || quote_ident(_extraneous_view);
        execute 'DROP VIEW '
            || quote_ident(OLD.schema_name) || '.' || quote_ident(_extraneous_view);
    end loop;

    raise debug 'Missing l10n views to create: %', _l10n_views_to_create;
    foreach _missing_view in array _l10n_views_to_create
    loop
        raise debug 'Creating missing l10n view: %', regexp_replace(_missing_view, '^.*([a-z]{2})$', '\1');
        call create_l10n_view(
            NEW.schema_name
            ,NEW.base_table_name
            ,NEW.l10n_table_name
            ,regexp_replace(_missing_view, '^.*([a-z]{2})$', '\1')
            ,false
        );
    end loop;

    if tg_op = 'DELETE' then
        if not coalesce(
                nullif(current_setting('pg_xenophile.in_l10n_table_event_trigger', true), ''),
                'false'
            )::bool
        then
            execute 'DROP TABLE '
                || quote_ident(OLD.schema_name) || '.' || quote_ident(OLD.l10n_table_name);

        end if;

        return OLD;
    end if;

    return NEW;
end;
$$;

comment on function l10n_table__maintain_l10n_objects() is
$md$The `l10n_table__maintain_l10n_objects()` trigger function is meant to actuate changes to the `l10_table` to the actual l10n tables and views tracked by that meta table.
$md$;

--------------------------------------------------------------------------------------------------------------

create trigger maintain_l10n_objects
    before insert or update or delete
    on l10n_table
    for each row
    execute function l10n_table__maintain_l10n_objects();

--------------------------------------------------------------------------------------------------------------

select pg_catalog.pg_extension_config_dump(
    'l10n_table',
    'WHERE l10n_table_belongs_to_extension_name IS NULL'
);

--------------------------------------------------------------------------------------------------------------

create or replace function l10n_table__track_alter_table_events()
    returns event_trigger
    security definer
    set search_path from current
    set pg_xenophile.in_l10n_table_event_trigger to true
    language plpgsql
    as $$
declare
    _ddl_command record;
    _dropped_obj record;
begin
    -- `pg_xenophile.pg_restore_seems_active` is set to true by `l10n_table__maintain_l10n_objects()` if that
    -- table trigger function thinks that we're restoring from a dump.  _It_ can (sort of) deduce that from
    -- seeing that an `INSERT` is actually a `COPY`, whereas _this_ event trigger will be triggered later
    -- during the restore, where we don't know how to detect that we're inside `pg_restore`.  (`pg_restore`
    -- sets the `application_name` to `psql`, sadly, which does make sense, since the final script will be a
    -- `psql` script.)
    if coalesce(nullif(current_setting('pg_xenophile.pg_restore_seems_active', true), '')::bool, false) then
        return;
    end if;

    for
        _ddl_command
    in select
        ddl_cmd.*
    from
        pg_event_trigger_ddl_commands() as ddl_cmd
    where
        ddl_cmd.classid = 'pg_class'::regclass
        and exists (
            select
            from
                l10n_table
            where
                l10n_table.base_table_regclass = ddl_cmd.objid
                or l10n_table.l10n_table_regclass = ddl_cmd.objid
        )
    loop
        update  l10n_table
        set     base_column_definitions =  (
                    select  base_column_definitions
                    from    l10n_table_with_fresh_ddl(l10n_table.*) as fresh
                )
        where   base_table_regclass = _ddl_command.objid
        ;

        update  l10n_table
        set     (l10n_table_constraint_definitions, l10n_column_definitions)
                =  (
                    select
                        l10n_table_constraint_definitions
                        ,l10n_column_definitions
                    from
                        l10n_table_with_fresh_ddl(l10n_table.*) as fresh
                )
        where
            l10n_table_regclass = _ddl_command.objid
        ;

        -- TODO: Handle `DROP TABLE` events in this same loop, as soon as pg_event_trigger_ddl_commands()
        --       is fixed to no longer return `NULL` for `DROP TABLE` events.
    end loop;
end;
$$;

--------------------------------------------------------------------------------------------------------------

create event trigger l10n_table__track_alter_table_events
    on ddl_command_end
    when TAG in ('ALTER TABLE')
    execute function l10n_table__track_alter_table_events();

--------------------------------------------------------------------------------------------------------------

create function l10n_table__track_drop_table_events()
    returns event_trigger
    security definer
    set search_path from current
    set pg_xenophile.in_l10n_table_event_trigger to true
    language plpgsql
    as $$
declare
    _dropped_obj record;
begin
    if coalesce(
            nullif(current_setting('pg_xenophile.in_l10n_table_row_trigger', true), ''),
            'false'
        )::bool
    then
        -- We are already responding to a `DELETE` to the row, so let's not doubly delete it.
        return;
    end if;

    for
        _dropped_obj
    in select
        dropped_obj.*
    from
        pg_event_trigger_dropped_objects() as dropped_obj
    where
        dropped_obj.classid = 'pg_class'::regclass
        and exists (
            select
            from
                l10n_table
            where
                l10n_table.base_table_regclass = dropped_obj.objid
                or l10n_table.l10n_table_regclass = dropped_obj.objid
        )
    loop
        delete from
            l10n_table
        where
            l10n_table.base_table_regclass = _dropped_obj.objid
            or l10n_table.l10n_table_regclass = _dropped_obj.objid
        ;
    end loop;
end;
$$;

--------------------------------------------------------------------------------------------------------------

create event trigger l10n_table__track_drop_table_events
    on sql_drop
    when TAG in ('DROP TABLE')
    execute function l10n_table__track_drop_table_events();

--------------------------------------------------------------------------------------------------------------

create or replace procedure test__l10n_table()
    set search_path from current
    set client_min_messages to 'WARNING'
    set plpgsql.check_asserts to true
    set pg_readme.include_this_routine_definition to true
    language plpgsql
    as $$
declare
    _row record;
    _l10n_table l10n_table;
begin
    -- Create the table that will be translated.
    create table test_uni (
        id bigint
            primary key
            generated always as identity
        ,uni_abbr text
            not null
            unique
        -- We need to have more than one non-PK column, to ensure that we're hitting the requirement to agg.
        -- Also, let's put a space in the column name, so that we're testing proper quoting as well.
        ,"student rating" bigint
            default 5
    );

    <<with_redundant_target_lang>>
    begin
        -- This tests that the trigger(s) on `l10n_table` tries to create the `_l10n_nl`-suffixed view
        -- only once and doesn't crash because of trying to create it twice.
        insert into l10n_table
            (base_table_name, l10n_column_definitions, base_lang_code, target_lang_codes)
        values (
            'test_uni'
            ,array['name TEXT NOT NULL', '"description (short)" TEXT NOT NULL']
            ,'nl'::lang_code_alpha2  -- Apologies for the Dutch East India Company mentality.
            ,array['nl']::lang_code_alpha2[]
        );
        raise transaction_rollback;
    exception
        when transaction_rollback then
    end with_redundant_target_lang;

    -- Register `test_uni` with the meta table, to activate all the l10n magic.
    insert into l10n_table
        (base_table_name, l10n_column_definitions, base_lang_code, target_lang_codes)
    values (
        'test_uni'
        ,array['name TEXT NOT NULL', '"description (short)" TEXT NOT NULL']
        ,'nl'::lang_code_alpha2  -- Apologies for the Dutch East India Company mentality.
        ,array['en', 'fr']::lang_code_alpha2[]
    );

    assert to_regclass('test_uni_l10n') is not null,
        'The `_l10n` table should have been created as result of the preceding INSERT into the meta table.';

    assert (
            select
                array_agg(pg_class.relname order by pg_class.relname)::name[]
            from
                pg_catalog.pg_class
            where
                pg_class.relkind = 'v'
                and pg_class.relnamespace = current_schema::regnamespace
                and pg_class.relname like 'test\_uni\_l10n\___'
        ) = array['test_uni_l10n_en', 'test_uni_l10n_fr', 'test_uni_l10n_nl']::name[]
        ,'3 `_l10n_<lang_code>`-suffixed views should have been created, one for the base language'
            || ' and 2 for the target languages.';

    <<upsert_into_l10n_lang_view>>
    declare
        _nl_expected record := row(
            1, 'AX-UNI', 5, 'nl', 'Bijl Universiteit', 'De trainingsleider in bijlonderhoud en gebruik'
        )::test_uni_l10n_nl;
        _en_expected record := row(
            1, 'AX-UNI', 5, 'en', 'Axe University', 'The leader in axe maintenance and usage training'
        )::test_uni_l10n_en;
    begin
        insert into test_uni_l10n_nl
            (uni_abbr, name, "description (short)")
        values
            (_nl_expected.uni_abbr, _nl_expected.name, _nl_expected."description (short)")
        returning
            *
        into
            _row
        ;

        assert _row = _nl_expected, format(
            'The `RETURNING` clause did not return the data as inserted; %s ≠ %s'
            ,_row, _nl_expected
        );

        assert _nl_expected = (select row(tbl.*)::test_uni_l10n_nl from test_uni_l10n_nl as tbl),
            'The `RETURNING` clause should have returned the same row data as this separate `SELECT`.';

        assert exists(select from test_uni_l10n_en where id = _nl_expected.id),
            'Even though the row for English doesn''t exist in `test_uni_l10n` yet, it should exist in the'
            ' `test_l10n_en` view, with NULL values for all the l10n columns.';

        update
            test_uni_l10n_en
        set
            "name" = _en_expected."name"
            ,"description (short)" = _en_expected."description (short)"
        where
            id = _nl_expected.id
        returning
            *
        into
            _row
        ;

        assert found, 'The `UPDATE` should have found a row to update in the `test_uni_l10n_en` view.';

        assert _row = _en_expected,
            format('%s ≠ %s; the `RETURNING` clause did not return the data as upserted.', _row, _en_expected);

        assert _en_expected = (select row(tbl.*)::test_uni_l10n_en from test_uni_l10n_en as tbl),
            'The `RETURNING` clause should have returned the same row data as this separate `SELECT`.';
    end upsert_into_l10n_lang_view;

    <<try_to_override_generated_pk>>
    declare
        _expected_id bigint := currval('test_uni_id_seq') + 1;
        _nl_expected record := row(
            _expected_id, 'SIMP-UNI', 2, 'nl', 'Simpschool', 'Simpen voor Elon en Jeff'
        )::test_uni_l10n_nl;
    begin
        insert into test_uni_l10n_nl
            (id, uni_abbr, "student rating", name, "description (short)")
        values (
            _nl_expected.id
            ,_nl_expected.uni_abbr
            ,_nl_expected."student rating"
            ,_nl_expected.name
            ,_nl_expected."description (short)"
        )
        returning
            *
        into
            _row
        ;

        raise assert_failure using
            message = 'It should not be possible to explicitly specify a PK value on insert'
                'if that PK is `GENERATED ALWAYS`.';
    exception
        when generated_always then
    end try_to_override_generated_pk;

    <<insert_instead_of_update_on_missing_l10n_record>>
    declare
        _expected_id bigint := currval('test_uni_id_seq') + 1;
        _nl_expected record := row(
            _expected_id, 'PO-UNI', 7, 'nl', 'Poep-Universiteit', 'De Beste Plek om Te Leren Legen'
        )::test_uni_l10n_nl;
        _en_expected record := row(
            _expected_id, 'PO-UNI', 7, 'en', 'Pooversity', 'The Best Place To Empty Yourself'
        )::test_uni_l10n_nl;
    begin
        insert into test_uni_l10n_nl
            (uni_abbr, "student rating", name, "description (short)")
        values (
            _nl_expected.uni_abbr
            ,_nl_expected."student rating"
            ,_nl_expected.name
            ,_nl_expected."description (short)"
        )
        returning
            *
        into
            _row
        ;

        -- Test that the trigger `test_uni_l10n_en` does an INSERT instead of an UPDATE if no row for this
        -- PK + lang_code combo exists yet in `test_uni_l10n`.
        update
            test_uni_l10n_en
        set
            uni_abbr = _en_expected.uni_abbr
            ,name = _en_expected.name
            ,"description (short)" = _en_expected."description (short)"
        where
            id = _en_expected.id
        returning
            *
        into
            _row
        ;

        assert _row = _en_expected, format('%s ≠ %s', _row, _en_expected);
    end insert_instead_of_update_on_missing_l10n_record;

    <<delete_via_l10n_view>>
    declare
        _expected_id bigint := currval('test_uni_id_seq') + 1;
        _fr_expected record := row(
            _expected_id, 'MOI-UNI', null, 'fr', 'Moiversitee', 'La Premier Bla'
        )::test_uni_l10n_fr;
    begin
        insert into test_uni_l10n_fr
            (uni_abbr, name, "description (short)")
        values
            (_fr_expected.uni_abbr, _fr_expected.name, _fr_expected."description (short)")
        returning
            *
        into
            _row
        ;
        delete from test_uni_l10n_fr where id = _row.id;
        assert found;
        assert not exists (select from test_uni where id = _row.id),
            'The base table record should have been deleted.';
        assert not exists (
                select from test_uni_l10n where id = _row.id and l10n_lang_code = _row.l10n_lang_code
            )
            ,'The l10n record should have been deleted, via the `ON DELETE CASCADE` to the base table.';
    end delete_via_l10n_view;

    <<trigger_alter_table_events>>
    begin
        alter table test_uni_l10n
            add description2 text;

        update test_uni_l10n
            set description2 = 'Something to satisfy NOT NULL';  -- Because we want to make it NOT NULL.

        alter table test_uni_l10n
            alter column description2 set not null;

        select * into _l10n_table from l10n_table where base_table_name = 'test_uni';

        assert _l10n_table.l10n_column_definitions[3] = 'description2 text NOT NULL',
            'The `l10n_table__track_alter_table_events` event trigger should have updated the list of l10n'
            ' columns.';

        assert exists(
                select
                from    pg_attribute
                where   attrelid = 'test_uni_l10n_fr'::regclass
                        and attname = 'description2'
            ), 'The `description2` column should have been added to the view.';

        alter table test_uni_l10n
            drop column description2
            cascade;

        select * into _l10n_table from l10n_table where base_table_name = 'test_uni';

        assert array_length(_l10n_table.l10n_column_definitions, 1) = 2,
            'The dropped column should have been removed from the `l10n_table` meta table.';

        assert not exists(
                select
                from    pg_attribute
                where   attrelid = 'test_uni_l10n_nl'::regclass
                        and attname = 'description2'
            ), 'The `description2` column should have disappeared from the views.';

        alter table test_uni
            add non_l10n_col int
                not null
                default 6;

        select * into _l10n_table from l10n_table where base_table_name = 'test_uni';

        assert _l10n_table.base_column_definitions[4] = 'non_l10n_col integer NOT NULL DEFAULT 6',
            'The `l10n_table__track_alter_table_events` event trigger should have updated the list of base'
            ' columns.';

        assert (select non_l10n_col from test_uni_l10n_nl where id = 2) = 6;

        alter table test_uni
            drop column non_l10n_col
            cascade;

        assert not exists(
                select
                from    pg_attribute
                where   attrelid = 'test_uni_l10n_nl'::regclass
                        and attname = 'non_l10n_col'
            ), 'The `non_l10n_col` column should have disappeared from the views.';

        <<add_base_column_with_default_value>>
        declare
            _nl_expected record;
        begin
            alter table test_uni
                add column base_col_with_default text
                    not null
                    default 'I am default.';

            alter table test_uni_l10n
                add column localized_image text
                    not null
                    default 'fallback.png';

            select * into _l10n_table from l10n_table where base_table_name = 'test_uni';

            assert _l10n_table.base_column_definitions[4]
                    = 'base_col_with_default text NOT NULL DEFAULT ''I am default.''::text',
                format(
                    'The `l10n_table__track_alter_table_events` event trigger should have updated the list of'
                    ' base columns; base_column_definitions = ''%s'''
                    ,_l10n_table.base_column_definitions
                );

            assert _l10n_table.l10n_column_definitions[3]
                    = 'localized_image text NOT NULL DEFAULT ''fallback.png''::text',
                format(
                    'The `l10n_table__track_alter_table_events` event trigger should have updated the list of'
                    ' l10n columns; l10n_column_definitions = ''%s'''
                    ,_l10n_table.l10n_column_definitions
                );

            -- Now, let's test how the defaults behave on insert…

            _nl_expected := row(
                1, 'HOF', 5, 'I am default.', 'nl', 'Wim Hof', 'De Ijsman', 'fallback.png'
            )::test_uni_l10n_nl;

            insert into test_uni_l10n_nl
                (uni_abbr, name, "description (short)")
            values
                (_nl_expected.uni_abbr, _nl_expected.name, _nl_expected."description (short)")
            returning
                *
            into
                _row
            ;

            assert _row.base_col_with_default = _nl_expected.base_col_with_default,
                'Default should have propegated from the base table to view.';
            assert _row.localized_image = _nl_expected.localized_image,
                'Default should have propegated from the l10n table to view.';
        end add_base_column_with_default_value;

        <<drop_base_table>>
        begin
            drop table test_uni cascade;

            assert not exists (select from l10n_table where base_table_name = 'test_uni');

            raise transaction_rollback;  -- I could have used any error code, but this one seemed to fit best.
        exception
            when transaction_rollback then
        end drop_base_table;
    end trigger_alter_table_events;

    -- DELETE-ing the meta info for our l10n table should cascade cleanly, without crashing.
    delete from l10n_table where base_table_regclass = 'test_uni'::regclass;

    assert to_regclass('test_uni_l10n') is null,
        'The actual `_l10n` table should have been removed when deleting the meta row from `l10n_table`.';

    <<insert_natural_key>>
    declare
        _expected record;
    begin
        -- Let's make a table with a natural primary key that is _not_ `GENERATED ALWAYS`.
        create table test_species (
            scientific_name text
                primary key
            -- Just so you know: without the `year_first_described` column, the `INSERT INTO l10n_table`
            -- would not trigger a certain bug, so please do not allow regressions to occur by removing
            -- this column.
            ,year_first_described int
        );

        -- Register `test_species` with the meta table, to activate all the l10n magic.
        insert into l10n_table
            (base_table_name, l10n_column_definitions, base_lang_code)
        values
            ('test_species' ,'{common_name TEXT}' ,'en')
        ;

        insert into test_species_l10n_en
            (scientific_name, common_name, year_first_described)
        values
            ('Taraxacum officinale', 'common dandelion', 1753)
        ;

        <<insert_duplicate_natural_key>>
        begin
            insert into test_species_l10n_en
                (scientific_name, common_name)
            values
                ('Taraxacum officinale', 'uncommon dandelion')
            ;
            raise assert_failure using message = 'Duplicating a primary key shouldn''t have been possible.';
        exception
            when unique_violation then
        end insert_duplicate_natural_key;
    end insert_natural_key;

    raise transaction_rollback;  -- I could have used any error code, but this one seemed to fit best.
exception
    when transaction_rollback then
end;
$$;

--------------------------------------------------------------------------------------------------------------

create or replace procedure test_dump_restore__l10n_table(test_stage$ text)
    set search_path from current
    set plpgsql.check_asserts to true
    language plpgsql
    as $$
declare
    _en_expected record;
    _nl_expected record;
    _pt_expected record;
    _es_expected record;
    _en_actual record;
    _nl_actual record;
    _pt_actual record;
    _es_actual record;
begin
    assert test_stage$ in ('pre-dump', 'post-restore');

    if test_stage$ = 'pre-dump' then
        -- Create the table that will be translated.
        create table test_uni (
            uni_abbr text
                primary key
        );

        insert into l10n_table
            (base_table_name, l10n_column_definitions, base_lang_code, target_lang_codes)
        values (
            'test_uni'
            ,array['name TEXT NOT NULL']
            ,'en'::lang_code_alpha2
            ,array['nl', 'fr']::lang_code_alpha2[]
        );

        assert to_regclass('test_uni_l10n') is not null,
            'The `_l10n` table should have been created as result of the preceding INSERT into the meta table.';
    end if;

    -- Set up the expected data, now that we for sure have the `test_uni_l10n_*` types,
    -- regardless of `test_stage$`.
    _en_expected := row('AX-UNI', 'en', 'Axe University')::test_uni_l10n_en;
    _nl_expected := row('AX-UNI', 'nl', 'Bijl Universiteit')::test_uni_l10n_nl;

    if test_stage$ = 'pre-dump' then
        insert into test_uni_l10n_en
            (uni_abbr, name)
        values
            (_en_expected.uni_abbr, _en_expected.name)
        returning
            *
        into
            _en_actual
        ;
        update
            test_uni_l10n_nl
        set
            name = _nl_expected.name
        where
            uni_abbr = _en_expected.uni_abbr
        returning
            *
        into
            _nl_actual
        ;
    elsif test_stage$ = 'post-restore' then
        select * into _en_actual from test_uni_l10n_en where uni_abbr = _en_expected.uni_abbr;
        select * into _nl_actual from test_uni_l10n_nl where uni_abbr = _nl_expected.uni_abbr;
    end if;

    assert _en_expected = _en_actual;
    assert _nl_expected = _nl_actual;

    --
    -- Go test a dependent extension (that has its own `l10n_table`) now…
    --

    if test_stage$ = 'pre-dump' then
        create extension l10n_table_dependent_extension;
    end if;

    _pt_expected := row(
        '👋'
        ,10
        ,false
        ,'pt'
        ,null
        ,null
        ,'tchau'
    )::subextension_tbl_l10n_pt;
    _es_expected := row(
        '👋'
        ,10
        ,false
        ,'es'
        ,null
        ,null
        ,'adiós'
    )::subextension_tbl_l10n_es;

    if test_stage$ = 'pre-dump' then
        insert into subextension_tbl_l10n_pt
            (natural_key, base_tbl_col, localized_text)
        values
            (_pt_expected.natural_key, _pt_expected.base_tbl_col, _pt_expected.localized_text)
        returning
            *
        into
            _pt_actual
        ;
        update
            subextension_tbl_l10n_es
        set
            localized_text = _es_expected.localized_text
        where
            natural_key = _es_expected.natural_key
        returning
            *
        into
            _es_actual
        ;
    elsif test_stage$ = 'post-restore' then
        select * into _pt_actual from subextension_tbl_l10n_pt where natural_key = _pt_expected.natural_key;
        select * into _es_actual from subextension_tbl_l10n_es where natural_key = _es_expected.natural_key;
    end if;

    assert _pt_actual = _pt_expected,
        format('%s != %s', _pt_actual, _pt_expected);
    assert _es_actual = _es_expected,
        format('%s != %s', _es_actual, _es_expected);

    --
    -- Test with the dependent subextension and a Portuguese row that has been inserted during installation…
    --

    _pt_expected := row(
        '👍'
        ,null
        ,true
        ,'pt'
        ,'l10n_table_dependent_extension'
        ,'forever'  -- Yes, this is a version string.
        ,'bem'
    )::subextension_tbl_l10n_pt;
    _es_expected := row(
        '👍'
        ,null
        ,true
        ,'es'
        ,null
        ,null
        ,'buen'
    )::subextension_tbl_l10n_es;

    if test_stage$ = 'pre-dump' then
        select * into _pt_actual from subextension_tbl_l10n_pt where natural_key = _pt_expected.natural_key;
        update
            subextension_tbl_l10n_es
        set
            localized_text = _es_expected.localized_text
        where
            natural_key = _es_expected.natural_key
        returning
            *
        into
            _es_actual
        ;
    elsif test_stage$ = 'post-restore' then
        select * into _pt_actual from subextension_tbl_l10n_pt where natural_key = _pt_expected.natural_key;
        select * into _es_actual from subextension_tbl_l10n_es where natural_key = _es_expected.natural_key;
    end if;

    assert _pt_actual = _pt_expected,
        format('%s != %s', _pt_actual, _pt_expected);
    assert _es_actual = _es_expected,
        format('%s != %s', _es_actual, _es_expected);
end;
$$;

comment on procedure test_dump_restore__l10n_table(text) is
$md$This procedure is to be called by the `test_dump_restore.sh` and `test_dump_restore.sql` companion scripts, once before `pg_dump` (with `test_stage$ = 'pre-dump'` argument) and once after `pg_restore` (with the `test_stage$ = 'post-restore'`).
$md$;

--------------------------------------------------------------------------------------------------------------

insert into l10n_table (
    base_table_name
    ,l10n_column_definitions
    ,base_lang_code, target_lang_codes
    ,l10n_table_belongs_to_extension_name
) values (
    'lang'
    ,array['name TEXT NOT NULL']
    ,'en'::lang_code_alpha2
    ,array[]::lang_code_alpha2[]
    ,'pg_xenophile'
);

-- We insert English first, because we need English for the FK in the `lang_l10n` table to work.
insert into lang_l10n_en
    (lang_code, "name", lang_belongs_to_pg_xenophile, l10n_columns_belong_to_extension_name)
values
    ('en', 'English', true, 'pg_xenophile')
;

insert into lang_l10n_en
    (lang_code, "name", lang_belongs_to_pg_xenophile, l10n_columns_belong_to_extension_name)
select
    v.lang_code_iso_639_1
    ,v.lang_name_en_wikipedia_primary
    ,true
    ,'pg_xenophile'
from (
    values
        ('ab', 'Abkhazian')
        ,('aa', 'Afar')
        ,('af', 'Afrikaans')
        ,('ak', 'Akan')
        ,('sq', 'Albanian')
        ,('am', 'Amharic')
        ,('ar', 'Arabic')
        ,('an', 'Aragonese')
        ,('hy', 'Armenian')
        ,('as', 'Assamese')
        ,('av', 'Avaric')
        ,('ae', 'Avestan')
        ,('ay', 'Aymara')
        ,('az', 'Azerbaijani')
        ,('bm', 'Bambara')
        ,('ba', 'Bashkir')
        ,('eu', 'Basque')
        ,('be', 'Belarusian')
        ,('bn', 'Bengali')
        ,('bi', 'Bislama')
        ,('bs', 'Bosnian')
        ,('br', 'Breton')
        ,('bg', 'Bulgarian')
        ,('my', 'Burmese')
        ,('ca', 'Catalan')
        ,('ch', 'Chamorro')
        ,('ce', 'Chechen')
        ,('ny', 'Chichewa')
        ,('zh', 'Chinese')
        ,('cu', 'Church Slavonic')
        ,('cv', 'Chuvash')
        ,('kw', 'Cornish')
        ,('co', 'Corsican')
        ,('cr', 'Cree')
        ,('hr', 'Croatian')
        ,('cs', 'Czech')
        ,('da', 'Danish')
        ,('dv', 'Divehi')
        ,('nl', 'Dutch')
        ,('dz', 'Dzongkha')
        --,('en', 'English')
        ,('eo', 'Esperanto')
        ,('et', 'Estonian')
        ,('ee', 'Ewe')
        ,('fo', 'Faroese')
        ,('fj', 'Fijian')
        ,('fi', 'Finnish')
        ,('fr', 'French')
        ,('fy', 'Western Frisian')
        ,('ff', 'Fulah')
        ,('gd', 'Gaelic')
        ,('gl', 'Galician')
        ,('lg', 'Ganda')
        ,('ka', 'Georgian')
        ,('de', 'German')
        ,('el', 'Greek')
        ,('kl', 'Kalaallisut')
        ,('gn', 'Guarani')
        ,('gu', 'Gujarati')
        ,('ht', 'Haitian')
        ,('ha', 'Hausa')
        ,('he', 'Hebrew')
        ,('hz', 'Herero')
        ,('hi', 'Hindi')
        ,('ho', 'Hiri Motu')
        ,('hu', 'Hungarian')
        ,('is', 'Icelandic')
        ,('io', 'Ido')
        ,('ig', 'Igbo')
        ,('id', 'Indonesian')
        ,('ia', 'Interlingua')
        ,('ie', 'Interlingue')
        ,('iu', 'Inuktitut')
        ,('ik', 'Inupiaq')
        ,('ga', 'Irish')
        ,('it', 'Italian')
        ,('ja', 'Japanese')
        ,('jv', 'Javanese')
        ,('kn', 'Kannada')
        ,('kr', 'Kanuri')
        ,('ks', 'Kashmiri')
        ,('kk', 'Kazakh')
        ,('km', 'Central Khmer')
        ,('ki', 'Kikuyu')
        ,('rw', 'Kinyarwanda')
        ,('ky', 'Kirghiz')
        ,('kv', 'Komi')
        ,('kg', 'Kongo')
        ,('ko', 'Korean')
        ,('kj', 'Kuanyama')
        ,('ku', 'Kurdish')
        ,('lo', 'Lao')
        ,('la', 'Latin')
        ,('lv', 'Latvian')
        ,('li', 'Limburgan')
        ,('ln', 'Lingala')
        ,('lt', 'Lithuanian')
        ,('lu', 'Luba-Katanga')
        ,('lb', 'Luxembourgish')
        ,('mk', 'Macedonian')
        ,('mg', 'Malagasy')
        ,('ms', 'Malay')
        ,('ml', 'Malayalam')
        ,('mt', 'Maltese')
        ,('gv', 'Manx')
        ,('mi', 'Maori')
        ,('mr', 'Marathi')
        ,('mh', 'Marshallese')
        ,('mn', 'Mongolian')
        ,('na', 'Nauru')
        ,('nv', 'Navaho')
        ,('nd', 'North Ndebele')
        ,('nr', 'South Ndebele')
        ,('ng', 'Ndonga')
        ,('ne', 'Nepali')
        ,('no', 'Norwegian')
        ,('nb', 'Norwegian Bokmål')
        ,('nn', 'Norwegian Nynorsk')
        ,('ii', 'Sichuan Yi')
        ,('oc', 'Occitan')
        ,('oj', 'Ojibwa')
        ,('or', 'Oriya')
        ,('om', 'Oromo')
        ,('os', 'Ossetian')
        ,('pi', 'Pali')
        ,('ps', 'Pashto')
        ,('fa', 'Persian')
        ,('pl', 'Polish')
        ,('pt', 'Portuguese')
        ,('pa', 'Punjabi')
        ,('qu', 'Quechua')
        ,('ro', 'Romanian')
        ,('rm', 'Romansh')
        ,('rn', 'Rundi')
        ,('ru', 'Russian')
        ,('se', 'Northern Sami')
        ,('sm', 'Samoan')
        ,('sg', 'Sango')
        ,('sa', 'Sanskrit')
        ,('sc', 'Sardinian')
        ,('sr', 'Serbian')
        ,('sn', 'Shona')
        ,('sd', 'Sindhi')
        ,('si', 'Sinhala')
        ,('sk', 'Slovak')
        ,('sl', 'Slovenian')
        ,('so', 'Somali')
        ,('st', 'Southern Sotho')
        ,('es', 'Spanish')
        ,('su', 'Sundanese')
        ,('sw', 'Swahili')
        ,('ss', 'Swati')
        ,('sv', 'Swedish')
        ,('tl', 'Tagalog')
        ,('ty', 'Tahitian')
        ,('tg', 'Tajik')
        ,('ta', 'Tamil')
        ,('tt', 'Tatar')
        ,('te', 'Telugu')
        ,('th', 'Thai')
        ,('bo', 'Tibetan')
        ,('ti', 'Tigrinya')
        ,('to', 'Tonga')
        ,('ts', 'Tsonga')
        ,('tn', 'Tswana')
        ,('tr', 'Turkish')
        ,('tk', 'Turkmen')
        ,('tw', 'Twi')
        ,('ug', 'Uighur')
        ,('uk', 'Ukrainian')
        ,('ur', 'Urdu')
        ,('uz', 'Uzbek')
        ,('ve', 'Venda')
        ,('vi', 'Vietnamese')
        ,('vo', 'Volapük')
        ,('wa', 'Walloon')
        ,('cy', 'Welsh')
        ,('wo', 'Wolof')
        ,('xh', 'Xhosa')
        ,('yi', 'Yiddish')
        ,('yo', 'Yoruba')
        ,('za', 'Zhuang')
        ,('zu', 'Zulu')
    ) as v (lang_code_iso_639_1, lang_name_en_wikipedia_primary)
;

--------------------------------------------------------------------------------------------------------------

insert into l10n_table (
    base_table_name
    ,l10n_column_definitions
    ,base_lang_code, target_lang_codes
    ,l10n_table_belongs_to_extension_name
) values (
    'country'::name
    ,array['name TEXT NOT NULL']
    ,'en'::lang_code_alpha2
    ,array[]::lang_code_alpha2[]
    ,'pg_xenophile'
);

-- Adapted from https://gist.github.com/ereli/0c94ec74a1807aaa895b912766556cc2 on 2022-06-13
insert into country_l10n_en (
    country_code, "name", country_code_alpha3, country_code_num, calling_code, currency_code,
    country_belongs_to_pg_xenophile, l10n_columns_belong_to_extension_name
) values
    ('AF', 'Afghanistan', 'AFG', '004', '093', 'EUR', true, 'pg_xenophile'),
    ('AL', 'Albania', 'ALB', '008', '355', 'EUR', true, 'pg_xenophile'),
    ('DZ', 'Algeria', 'DZA', '012', '213', 'EUR', true, 'pg_xenophile'),
    ('AS', 'American Samoa', 'ASM', '016', 1684, 'EUR', true, 'pg_xenophile'),
    ('AD', 'Andorra', 'AND', '020', '376', 'EUR', true, 'pg_xenophile'),
    ('AO', 'Angola', 'AGO', '024', '244', 'EUR', true, 'pg_xenophile'),
    ('AI', 'Anguilla', 'AIA', '660', 1264, 'EUR', true, 'pg_xenophile'),
    ('AQ', 'Antarctica', 'ATA', '010', 0, 'EUR', true, 'pg_xenophile'),
    ('AG', 'Antigua and Barbuda', 'ATG', '028', 1268, 'EUR', true, 'pg_xenophile'),
    ('AR', 'Argentina', 'ARG', '032', 54, 'EUR', true, 'pg_xenophile'),
    ('AM', 'Armenia', 'ARM', '051', 374, 'EUR', true, 'pg_xenophile'),
    ('AW', 'Aruba', 'ABW', '533', 297, 'EUR', true, 'pg_xenophile'),
    ('AU', 'Australia', 'AUS', '036', 61, 'EUR', true, 'pg_xenophile'),
    ('AT', 'Austria', 'AUT', '040', 43, 'EUR', true, 'pg_xenophile'),
    ('AZ', 'Azerbaijan', 'AZE', '031', 994, 'EUR', true, 'pg_xenophile'),
    ('BS', 'Bahamas', 'BHS', '044', 1242, 'EUR', true, 'pg_xenophile'),
    ('BH', 'Bahrain', 'BHR', '048', 973, 'EUR', true, 'pg_xenophile'),
    ('BD', 'Bangladesh', 'BGD', '050', 880, 'EUR', true, 'pg_xenophile'),
    ('BB', 'Barbados', 'BRB', '052', 1246, 'EUR', true, 'pg_xenophile'),
    ('BY', 'Belarus', 'BLR', '112', 375, 'EUR', true, 'pg_xenophile'),
    ('BE', 'Belgium', 'BEL', '056', 32, 'EUR', true, 'pg_xenophile'),
    ('BZ', 'Belize', 'BLZ', '084', 501, 'EUR', true, 'pg_xenophile'),
    ('BJ', 'Benin', 'BEN', '204', 229, 'EUR', true, 'pg_xenophile'),
    ('BM', 'Bermuda', 'BMU', '060', 1441, 'EUR', true, 'pg_xenophile'),
    ('BT', 'Bhutan', 'BTN', '064', 975, 'EUR', true, 'pg_xenophile'),
    ('BO', 'Bolivia', 'BOL', '068', 591, 'EUR', true, 'pg_xenophile'),
    ('BA', 'Bosnia and Herzegovina', 'BIH', '070', 387, 'EUR', true, 'pg_xenophile'),
    ('BW', 'Botswana', 'BWA', '072', 267, 'EUR', true, 'pg_xenophile'),
    ('BV', 'Bouvet Island', 'BVT', '074', 0, 'EUR', true, 'pg_xenophile'),
    ('BR', 'Brazil', 'BRA', '076', 55, 'EUR', true, 'pg_xenophile'),
    ('IO', 'British Indian Ocean Territory', 'IOT', '086', 246, 'EUR', true, 'pg_xenophile'),
    ('BN', 'Brunei Darussalam', 'BRN', '096', 673, 'EUR', true, 'pg_xenophile'),
    ('BG', 'Bulgaria', 'BGR', '100', 359, 'EUR', true, 'pg_xenophile'),
    ('BF', 'Burkina Faso', 'BFA', '854', 226, 'EUR', true, 'pg_xenophile'),
    ('BI', 'Burundi', 'BDI', '108', 257, 'EUR', true, 'pg_xenophile'),
    ('KH', 'Cambodia', 'KHM', '116', 855, 'EUR', true, 'pg_xenophile'),
    ('CM', 'Cameroon', 'CMR', '120', 237, 'EUR', true, 'pg_xenophile'),
    ('CA', 'Canada', 'CAN', '124', 1, 'EUR', true, 'pg_xenophile'),
    ('CV', 'Cape Verde', 'CPV', '132', 238, 'EUR', true, 'pg_xenophile'),
    ('KY', 'Cayman Islands', 'CYM', '136', 1345, 'EUR', true, 'pg_xenophile'),
    ('CF', 'Central African Republic', 'CAF', '140', 236, 'EUR', true, 'pg_xenophile'),
    ('TD', 'Chad', 'TCD', '148', 235, 'EUR', true, 'pg_xenophile'),
    ('CL', 'Chile', 'CHL', '152', 56, 'EUR', true, 'pg_xenophile'),
    ('CN', 'China', 'CHN', '156', 86, 'EUR', true, 'pg_xenophile'),
    ('CX', 'Christmas Island', 'CXR', '162', 61, 'EUR', true, 'pg_xenophile'),
    --('CC', 'Cocos (Keeling) Islands', NULL, NULL, 672, 'EUR', true, 'pg_xenophile'),
    ('CO', 'Colombia', 'COL', '170', 57, 'EUR', true, 'pg_xenophile'),
    ('KM', 'Comoros', 'COM', '174', 269, 'EUR', true, 'pg_xenophile'),
    ('CG', 'Congo', 'COG', '178', 242, 'EUR', true, 'pg_xenophile'),
    ('CD', 'Congo, the Democratic Republic of the', 'COD', '180', 242, 'EUR', true, 'pg_xenophile'),
    ('CK', 'Cook Islands', 'COK', '184', 682, 'EUR', true, 'pg_xenophile'),
    ('CR', 'Costa Rica', 'CRI', '188', 506, 'EUR', true, 'pg_xenophile'),
    ('CI', 'Cote D''Ivoire', 'CIV', '384', 225, 'EUR', true, 'pg_xenophile'),
    ('HR', 'Croatia', 'HRV', '191', 385, 'EUR', true, 'pg_xenophile'),
    ('CU', 'Cuba', 'CUB', '192', 53, 'EUR', true, 'pg_xenophile'),
    ('CY', 'Cyprus', 'CYP', '196', 357, 'EUR', true, 'pg_xenophile'),
    ('CZ', 'Czech Republic', 'CZE', '203', 420, 'EUR', true, 'pg_xenophile'),
    ('DK', 'Denmark', 'DNK', '208', 45, 'EUR', true, 'pg_xenophile'),
    ('DJ', 'Djibouti', 'DJI', '262', 253, 'EUR', true, 'pg_xenophile'),
    ('DM', 'Dominica', 'DMA', '212', 1767, 'EUR', true, 'pg_xenophile'),
    ('DO', 'Dominican Republic', 'DOM', '214', 1, 'EUR', true, 'pg_xenophile'),
    ('EC', 'Ecuador', 'ECU', '218', 593, 'EUR', true, 'pg_xenophile'),
    ('EG', 'Egypt', 'EGY', '818', 20, 'EUR', true, 'pg_xenophile'),
    ('SV', 'El Salvador', 'SLV', '222', 503, 'EUR', true, 'pg_xenophile'),
    ('GQ', 'Equatorial Guinea', 'GNQ', '226', 240, 'EUR', true, 'pg_xenophile'),
    ('ER', 'Eritrea', 'ERI', '232', 291, 'EUR', true, 'pg_xenophile'),
    ('EE', 'Estonia', 'EST', '233', 372, 'EUR', true, 'pg_xenophile'),
    ('ET', 'Ethiopia', 'ETH', '231', 251, 'EUR', true, 'pg_xenophile'),
    ('FK', 'Falkland Islands (Malvinas)', 'FLK', '238', 500, 'EUR', true, 'pg_xenophile'),
    ('FO', 'Faroe Islands', 'FRO', '234', 298, 'EUR', true, 'pg_xenophile'),
    ('FJ', 'Fiji', 'FJI', '242', 679, 'EUR', true, 'pg_xenophile'),
    ('FI', 'Finland', 'FIN', '246', 358, 'EUR', true, 'pg_xenophile'),
    ('FR', 'France', 'FRA', '250', 33, 'EUR', true, 'pg_xenophile'),
    ('GF', 'French Guiana', 'GUF', '254', 594, 'EUR', true, 'pg_xenophile'),
    ('PF', 'French Polynesia', 'PYF', '258', 689, 'EUR', true, 'pg_xenophile'),
    ('TF', 'French Southern Territories', 'ATF', '260', 0, 'EUR', true, 'pg_xenophile'),
    ('GA', 'Gabon', 'GAB', '266', 241, 'EUR', true, 'pg_xenophile'),
    ('GM', 'Gambia', 'GMB', '270', 220, 'EUR', true, 'pg_xenophile'),
    ('GE', 'Georgia', 'GEO', '268', 995, 'EUR', true, 'pg_xenophile'),
    ('DE', 'Germany', 'DEU', '276', 49, 'EUR', true, 'pg_xenophile'),
    ('GH', 'Ghana', 'GHA', '288', 233, 'EUR', true, 'pg_xenophile'),
    ('GI', 'Gibraltar', 'GIB', '292', 350, 'EUR', true, 'pg_xenophile'),
    ('GR', 'Greece', 'GRC', '300', 30, 'EUR', true, 'pg_xenophile'),
    ('GL', 'Greenland', 'GRL', '304', 299, 'EUR', true, 'pg_xenophile'),
    ('GD', 'Grenada', 'GRD', '308', 1473, 'EUR', true, 'pg_xenophile'),
    ('GP', 'Guadeloupe', 'GLP', '312', 590, 'EUR', true, 'pg_xenophile'),
    ('GU', 'Guam', 'GUM', '316', 1671, 'EUR', true, 'pg_xenophile'),
    ('GT', 'Guatemala', 'GTM', '320', 502, 'EUR', true, 'pg_xenophile'),
    ('GN', 'Guinea', 'GIN', '324', 224, 'EUR', true, 'pg_xenophile'),
    ('GW', 'Guinea-Bissau', 'GNB', '624', 245, 'EUR', true, 'pg_xenophile'),
    ('GY', 'Guyana', 'GUY', '328', 592, 'EUR', true, 'pg_xenophile'),
    ('HT', 'Haiti', 'HTI', '332', 509, 'EUR', true, 'pg_xenophile'),
    ('HM', 'Heard Island and Mcdonald Islands', 'HMD', '334', 0, 'EUR', true, 'pg_xenophile'),
    ('VA', 'Holy See (Vatican City State)', 'VAT', '336', 39, 'EUR', true, 'pg_xenophile'),
    ('HN', 'Honduras', 'HND', '340', 504, 'EUR', true, 'pg_xenophile'),
    ('HK', 'Hong Kong', 'HKG', '344', 852, 'EUR', true, 'pg_xenophile'),
    ('HU', 'Hungary', 'HUN', '348', 36, 'EUR', true, 'pg_xenophile'),
    ('IS', 'Iceland', 'ISL', '352', 354, 'EUR', true, 'pg_xenophile'),
    ('IN', 'India', 'IND', '356', 91, 'EUR', true, 'pg_xenophile'),
    ('ID', 'Indonesia', 'IDN', '360', 62, 'EUR', true, 'pg_xenophile'),
    ('IR', 'Iran, Islamic Republic of', 'IRN', '364', 98, 'EUR', true, 'pg_xenophile'),
    ('IQ', 'Iraq', 'IRQ', '368', 964, 'EUR', true, 'pg_xenophile'),
    ('IE', 'Ireland', 'IRL', '372', 353, 'EUR', true, 'pg_xenophile'),
    ('IL', 'Israel', 'ISR', '376', 972, 'EUR', true, 'pg_xenophile'),
    ('IT', 'Italy', 'ITA', '380', 39, 'EUR', true, 'pg_xenophile'),
    ('JM', 'Jamaica', 'JAM', '388', 1876, 'EUR', true, 'pg_xenophile'),
    ('JP', 'Japan', 'JPN', '392', 81, 'EUR', true, 'pg_xenophile'),
    ('JO', 'Jordan', 'JOR', '400', 962, 'EUR', true, 'pg_xenophile'),
    ('KZ', 'Kazakhstan', 'KAZ', '398', 7, 'EUR', true, 'pg_xenophile'),
    ('KE', 'Kenya', 'KEN', '404', 254, 'EUR', true, 'pg_xenophile'),
    ('KI', 'Kiribati', 'KIR', '296', 686, 'EUR', true, 'pg_xenophile'),
    ('KP', 'Korea, Democratic People''s Republic of', 'PRK', '408', 850, 'EUR', true, 'pg_xenophile'),
    ('KR', 'Korea, Republic of', 'KOR', '410', 82, 'EUR', true, 'pg_xenophile'),
    ('KW', 'Kuwait', 'KWT', '414', 965, 'EUR', true, 'pg_xenophile'),
    ('KG', 'Kyrgyzstan', 'KGZ', '417', 996, 'EUR', true, 'pg_xenophile'),
    ('LA', 'Lao People''s Democratic Republic', 'LAO', '418', 856, 'EUR', true, 'pg_xenophile'),
    ('LV', 'Latvia', 'LVA', '428', 371, 'EUR', true, 'pg_xenophile'),
    ('LB', 'Lebanon', 'LBN', '422', 961, 'EUR', true, 'pg_xenophile'),
    ('LS', 'Lesotho', 'LSO', '426', 266, 'EUR', true, 'pg_xenophile'),
    ('LR', 'Liberia', 'LBR', '430', 231, 'EUR', true, 'pg_xenophile'),
    ('LY', 'Libyan Arab Jamahiriya', 'LBY', '434', 218, 'EUR', true, 'pg_xenophile'),
    ('LI', 'Liechtenstein', 'LIE', '438', 423, 'EUR', true, 'pg_xenophile'),
    ('LT', 'Lithuania', 'LTU', '440', 370, 'EUR', true, 'pg_xenophile'),
    ('LU', 'Luxembourg', 'LUX', '442', 352, 'EUR', true, 'pg_xenophile'),
    ('MO', 'Macao', 'MAC', '446', 853, 'EUR', true, 'pg_xenophile'),
    ('MK', 'North Macedonia', 'MKD', '807', 389, 'EUR', true, 'pg_xenophile'),
    ('MG', 'Madagascar', 'MDG', '450', 261, 'EUR', true, 'pg_xenophile'),
    ('MW', 'Malawi', 'MWI', '454', 265, 'EUR', true, 'pg_xenophile'),
    ('MY', 'Malaysia', 'MYS', '458', 60, 'EUR', true, 'pg_xenophile'),
    ('MV', 'Maldives', 'MDV', '462', 960, 'EUR', true, 'pg_xenophile'),
    ('ML', 'Mali', 'MLI', '466', 223, 'EUR', true, 'pg_xenophile'),
    ('MT', 'Malta', 'MLT', '470', 356, 'EUR', true, 'pg_xenophile'),
    ('MH', 'Marshall Islands', 'MHL', '584', 692, 'EUR', true, 'pg_xenophile'),
    ('MQ', 'Martinique', 'MTQ', '474', 596, 'EUR', true, 'pg_xenophile'),
    ('MR', 'Mauritania', 'MRT', '478', 222, 'EUR', true, 'pg_xenophile'),
    ('MU', 'Mauritius', 'MUS', '480', 230, 'EUR', true, 'pg_xenophile'),
    ('YT', 'Mayotte', 'MYT', '175', 269, 'EUR', true, 'pg_xenophile'),
    ('MX', 'Mexico', 'MEX', '484', 52, 'EUR', true, 'pg_xenophile'),
    ('FM', 'Micronesia, Federated States of', 'FSM', '583', 691, 'EUR', true, 'pg_xenophile'),
    ('MD', 'Moldova, Republic of', 'MDA', '498', 373, 'EUR', true, 'pg_xenophile'),
    ('MC', 'Monaco', 'MCO', '492', 377, 'EUR', true, 'pg_xenophile'),
    ('MN', 'Mongolia', 'MNG', '496', 976, 'EUR', true, 'pg_xenophile'),
    ('MS', 'Montserrat', 'MSR', '500', 1664, 'EUR', true, 'pg_xenophile'),
    ('MA', 'Morocco', 'MAR', '504', 212, 'EUR', true, 'pg_xenophile'),
    ('MZ', 'Mozambique', 'MOZ', '508', 258, 'EUR', true, 'pg_xenophile'),
    ('MM', 'Myanmar', 'MMR', '104', 95, 'EUR', true, 'pg_xenophile'),
    ('NA', 'Namibia', 'NAM', '516', 264, 'EUR', true, 'pg_xenophile'),
    ('NR', 'Nauru', 'NRU', '520', 674, 'EUR', true, 'pg_xenophile'),
    ('NP', 'Nepal', 'NPL', '524', 977, 'EUR', true, 'pg_xenophile'),
    ('NL', 'Netherlands', 'NLD', '528', 31, 'EUR', true, 'pg_xenophile'),
    ('AN', 'Netherlands Antilles', 'ANT', '530', 599, 'EUR', true, 'pg_xenophile'),
    ('NC', 'New Caledonia', 'NCL', '540', 687, 'EUR', true, 'pg_xenophile'),
    ('NZ', 'New Zealand', 'NZL', '554', 64, 'EUR', true, 'pg_xenophile'),
    ('NI', 'Nicaragua', 'NIC', '558', 505, 'EUR', true, 'pg_xenophile'),
    ('NE', 'Niger', 'NER', '562', 227, 'EUR', true, 'pg_xenophile'),
    ('NG', 'Nigeria', 'NGA', '566', 234, 'EUR', true, 'pg_xenophile'),
    ('NU', 'Niue', 'NIU', '570', 683, 'EUR', true, 'pg_xenophile'),
    ('NF', 'Norfolk Island', 'NFK', '574', 672, 'EUR', true, 'pg_xenophile'),
    ('MP', 'Northern Mariana Islands', 'MNP', '580', 1670, 'EUR', true, 'pg_xenophile'),
    ('NO', 'Norway', 'NOR', '578', 47, 'EUR', true, 'pg_xenophile'),
    ('OM', 'Oman', 'OMN', '512', 968, 'EUR', true, 'pg_xenophile'),
    ('PK', 'Pakistan', 'PAK', '586', 92, 'EUR', true, 'pg_xenophile'),
    ('PW', 'Palau', 'PLW', '585', 680, 'EUR', true, 'pg_xenophile'),
    --('PS', 'Palestinian Territory, Occupied', NULL, NULL, 970, 'EUR', true, 'pg_xenophile'),
    ('PA', 'Panama', 'PAN', '591', 507, 'EUR', true, 'pg_xenophile'),
    ('PG', 'Papua New Guinea', 'PNG', '598', 675, 'EUR', true, 'pg_xenophile'),
    ('PY', 'Paraguay', 'PRY', '600', 595, 'EUR', true, 'pg_xenophile'),
    ('PE', 'Peru', 'PER', '604', 51, 'EUR', true, 'pg_xenophile'),
    ('PH', 'Philippines', 'PHL', '608', 63, 'EUR', true, 'pg_xenophile'),
    ('PN', 'Pitcairn', 'PCN', '612', 0, 'EUR', true, 'pg_xenophile'),
    ('PL', 'Poland', 'POL', '616', 48, 'EUR', true, 'pg_xenophile'),
    ('PT', 'Portugal', 'PRT', '620', 351, 'EUR', true, 'pg_xenophile'),
    ('PR', 'Puerto Rico', 'PRI', '630', 1787, 'EUR', true, 'pg_xenophile'),
    ('QA', 'Qatar', 'QAT', '634', 974, 'EUR', true, 'pg_xenophile'),
    ('RE', 'Reunion', 'REU', '638', 262, 'EUR', true, 'pg_xenophile'),
    ('RO', 'Romania', 'ROU', '642', 40, 'EUR', true, 'pg_xenophile'),
    ('RU', 'Russian Federation', 'RUS', '643', 7, 'EUR', true, 'pg_xenophile'),
    ('RW', 'Rwanda', 'RWA', '646', 250, 'EUR', true, 'pg_xenophile'),
    ('SH', 'Saint Helena', 'SHN', '654', 290, 'EUR', true, 'pg_xenophile'),
    ('KN', 'Saint Kitts and Nevis', 'KNA', '659', 1869, 'EUR', true, 'pg_xenophile'),
    ('LC', 'Saint Lucia', 'LCA', '662', 1758, 'EUR', true, 'pg_xenophile'),
    ('PM', 'Saint Pierre and Miquelon', 'SPM', '666', 508, 'EUR', true, 'pg_xenophile'),
    ('VC', 'Saint Vincent and the Grenadines', 'VCT', '670', 1784, 'EUR', true, 'pg_xenophile'),
    ('WS', 'Samoa', 'WSM', '882', 684, 'EUR', true, 'pg_xenophile'),
    ('SM', 'San Marino', 'SMR', '674', 378, 'EUR', true, 'pg_xenophile'),
    ('ST', 'Sao Tome and Principe', 'STP', '678', 239, 'EUR', true, 'pg_xenophile'),
    ('SA', 'Saudi Arabia', 'SAU', '682', 966, 'EUR', true, 'pg_xenophile'),
    ('SN', 'Senegal', 'SEN', '686', 221, 'EUR', true, 'pg_xenophile'),
    ('RS', 'Serbia', 'SRB', '688', 381, 'EUR', true, 'pg_xenophile'),
    ('SC', 'Seychelles', 'SYC', '690', 248, 'EUR', true, 'pg_xenophile'),
    ('SL', 'Sierra Leone', 'SLE', '694', 232, 'EUR', true, 'pg_xenophile'),
    ('SG', 'Singapore', 'SGP', '702', 65, 'EUR', true, 'pg_xenophile'),
    ('SK', 'Slovakia', 'SVK', '703', 421, 'EUR', true, 'pg_xenophile'),
    ('SI', 'Slovenia', 'SVN', '705', 386, 'EUR', true, 'pg_xenophile'),
    ('SB', 'Solomon Islands', 'SLB', '090', 677, 'EUR', true, 'pg_xenophile'),
    ('SO', 'Somalia', 'SOM', '706', 252, 'EUR', true, 'pg_xenophile'),
    ('ZA', 'South Africa', 'ZAF', '710', 27, 'EUR', true, 'pg_xenophile'),
    ('GS', 'South Georgia and the South Sandwich Islands', 'SGS', '239', 0, 'EUR', true, 'pg_xenophile'),
    ('ES', 'Spain', 'ESP', '724', 34, 'EUR', true, 'pg_xenophile'),
    ('LK', 'Sri Lanka', 'LKA', '144', 94, 'EUR', true, 'pg_xenophile'),
    ('SD', 'Sudan', 'SDN', '736', 249, 'EUR', true, 'pg_xenophile'),
    ('SR', 'Suriname', 'SUR', '740', 597, 'EUR', true, 'pg_xenophile'),
    ('SJ', 'Svalbard and Jan Mayen', 'SJM', '744', 47, 'EUR', true, 'pg_xenophile'),
    ('SZ', 'Swaziland', 'SWZ', '748', 268, 'EUR', true, 'pg_xenophile'),
    ('SE', 'Sweden', 'SWE', '752', 46, 'EUR', true, 'pg_xenophile'),
    ('CH', 'Switzerland', 'CHE', '756', 41, 'EUR', true, 'pg_xenophile'),
    ('SY', 'Syrian Arab Republic', 'SYR', '760', 963, 'EUR', true, 'pg_xenophile'),
    ('TW', 'Taiwan, Province of China', 'TWN', '158', 886, 'EUR', true, 'pg_xenophile'),
    ('TJ', 'Tajikistan', 'TJK', '762', 992, 'EUR', true, 'pg_xenophile'),
    ('TZ', 'Tanzania, United Republic of', 'TZA', '834', 255, 'EUR', true, 'pg_xenophile'),
    ('TH', 'Thailand', 'THA', '764', 66, 'EUR', true, 'pg_xenophile'),
    ('TL', 'Timor-Leste', 'TLS', '626', 670, 'EUR', true, 'pg_xenophile'),
    ('TG', 'Togo', 'TGO', '768', 228, 'EUR', true, 'pg_xenophile'),
    ('TK', 'Tokelau', 'TKL', '772', 690, 'EUR', true, 'pg_xenophile'),
    ('TO', 'Tonga', 'TON', '776', 676, 'EUR', true, 'pg_xenophile'),
    ('TT', 'Trinidad and Tobago', 'TTO', '780', 1868, 'EUR', true, 'pg_xenophile'),
    ('TN', 'Tunisia', 'TUN', '788', 216, 'EUR', true, 'pg_xenophile'),
    ('TR', 'Turkey', 'TUR', '792', 90, 'EUR', true, 'pg_xenophile'),
    ('TM', 'Turkmenistan', 'TKM', '795', 993, 'EUR', true, 'pg_xenophile'),
    ('TC', 'Turks and Caicos Islands', 'TCA', '796', 1649, 'EUR', true, 'pg_xenophile'),
    ('TV', 'Tuvalu', 'TUV', '798', 688, 'EUR', true, 'pg_xenophile'),
    ('UG', 'Uganda', 'UGA', '800', 256, 'EUR', true, 'pg_xenophile'),
    ('UA', 'Ukraine', 'UKR', '804', 380, 'EUR', true, 'pg_xenophile'),
    ('AE', 'United Arab Emirates', 'ARE', '784', 971, 'EUR', true, 'pg_xenophile'),
    ('GB', 'United Kingdom', 'GBR', '826', 44, 'EUR', true, 'pg_xenophile'),
    ('US', 'United States', 'USA', '840', 1, 'EUR', true, 'pg_xenophile'),
    ('UM', 'United States Minor Outlying Islands', 'UMI', '581', 1, 'EUR', true, 'pg_xenophile'),
    ('UY', 'Uruguay', 'URY', '858', 598, 'EUR', true, 'pg_xenophile'),
    ('UZ', 'Uzbekistan', 'UZB', '860', 998, 'EUR', true, 'pg_xenophile'),
    ('VU', 'Vanuatu', 'VUT', '548', 678, 'EUR', true, 'pg_xenophile'),
    ('VE', 'Venezuela', 'VEN', '862', 58, 'EUR', true, 'pg_xenophile'),
    ('VN', 'Viet Nam', 'VNM', '704', 84, 'EUR', true, 'pg_xenophile'),
    ('VG', 'Virgin Islands, British', 'VGB', '092', 1284, 'EUR', true, 'pg_xenophile'),
    ('VI', 'Virgin Islands, U.s.', 'VIR', '850', 1340, 'EUR', true, 'pg_xenophile'),
    ('WF', 'Wallis and Futuna', 'WLF', '876', 681, 'EUR', true, 'pg_xenophile'),
    ('EH', 'Western Sahara', 'ESH', '732', 212, 'EUR', true, 'pg_xenophile'),
    ('YE', 'Yemen', 'YEM', '887', 967, 'EUR', true, 'pg_xenophile'),
    ('ZM', 'Zambia', 'ZMB', '894', 260, 'EUR', true, 'pg_xenophile'),
    ('ZW', 'Zimbabwe', 'ZWE', '716', 263, 'EUR', true, 'pg_xenophile'),
    ('ME', 'Montenegro', 'MNE', '499', 382, 'EUR', true, 'pg_xenophile'),
    ('XK', 'Kosovo', 'XKX', '000', 383, 'EUR', true, 'pg_xenophile'),
    ('AX', 'Aland Islands', 'ALA', '248', '358', 'EUR', true, 'pg_xenophile'),
    ('BQ', 'Bonaire, Sint Eustatius and Saba', 'BES', '535', '599', 'EUR', true, 'pg_xenophile'),
    ('CW', 'Curacao', 'CUW', '531', '599', 'EUR', true, 'pg_xenophile'),
    ('GG', 'Guernsey', 'GGY', '831', '44', 'EUR', true, 'pg_xenophile'),
    ('IM', 'Isle of Man', 'IMN', '833', '44', 'EUR', true, 'pg_xenophile'),
    ('JE', 'Jersey', 'JEY', '832', '44', 'EUR', true, 'pg_xenophile'),
    ('BL', 'Saint Barthelemy', 'BLM', '652', '590', 'EUR', true, 'pg_xenophile'),
    ('MF', 'Saint Martin', 'MAF', '663', '590', 'EUR', true, 'pg_xenophile'),
    ('SX', 'Sint Maarten', 'SXM', '534', '1', 'EUR', true, 'pg_xenophile'),
    ('SS', 'South Sudan', 'SSD', '728', '211', 'EUR', true, 'pg_xenophile');

--------------------------------------------------------------------------------------------------------------

insert into country_postal_code_pattern (
    country_code
    ,valid_postal_code_regexp
    ,clean_postal_code_regexp
    ,clean_postal_code_replace
    ,postal_code_example
    ,postal_code_pattern_checked_on
    ,postal_code_pattern_information_source
    ,postal_code_pattern_belongs_to_pg_xenophile
) values (
    'NL'
    ,'^[0-9]{4} [A-Z]{2}$'
    ,'^([0-9]{4}) ?([A-Z]{2})(?<!SA|SD|SS)$'
    ,'\1\2'
    ,'1234 AB'
    ,'2022-08-20'
    ,'https://nl.wikipedia.org/wiki/Postcodes_in_Nederland'
        ' and https://nl.wikipedia.org/wiki/Postcode#Postcodes_in_Nederland'
    ,true
),(
    'PT'
    ,'^[0-9]{5}-[0-9]{3}$'
    ,null
    ,null
    ,'1000-205'
    ,'2023-01-02'
    ,'https://en.wikipedia.org/wiki/Postal_codes_in_Portugal'
    ,true
);

--------------------------------------------------------------------------------------------------------------

-- Source: https://www.rijksoverheid.nl/onderwerpen/europese-unie/vraag-en-antwoord/welke-landen-horen-bij-de-europese-unie-eu retrieved on 2022-07-30
insert into eu_country(country_code, eu_membership_checked_on, eu_country_belongs_to_pg_xenophile)
values
    ('BE', '2022-07-30', true),
    ('BG', '2022-07-30', true),
    ('CY', '2022-07-30', true),
    ('DK', '2022-07-30', true),
    ('DE', '2022-07-30', true),
    ('EE', '2022-07-30', true),
    ('FI', '2022-07-30', true),
    ('FR', '2022-07-30', true),
    ('GR', '2022-07-30', true),
    ('HU', '2022-07-30', true),
    ('IE', '2022-07-30', true),
    ('IT', '2022-07-30', true),
    ('HR', '2022-07-30', true),
    ('LV', '2022-07-30', true),
    ('LT', '2022-07-30', true),
    ('LU', '2022-07-30', true),
    ('MT', '2022-07-30', true),
    ('NL', '2022-07-30', true),
    ('AT', '2022-07-30', true),
    ('PL', '2022-07-30', true),
    ('PT', '2022-07-30', true),
    ('RO', '2022-07-30', true),
    ('SI', '2022-07-30', true),
    ('SK', '2022-07-30', true),
    ('ES', '2022-07-30', true),
    ('CZ', '2022-07-30', true),
    ('SE', '2022-07-30', true);

--------------------------------------------------------------------------------------------------------------
