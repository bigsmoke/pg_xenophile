/*
This file is part of the `pg_xenophile` PostgreSQL extension.
Copyright © 2022 Rowan Rodrik van der Molen.

`pg_xenophile` is free software: you can redistribute it and/or modify it
under the terms of the GNU Affero General Public License as published by the
Free Software Foundation, either version 3 of the License, or (at your
 option) any later version.

 `pg_xenophile` is distributed in the hope that it will be useful, but WITHOUT
 ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
 details.

You should have received a copy of the GNU Affero General Public License
along with `pg_xenophile`. If not, see <https://www.gnu.org/licenses/>.
*/

--------------------------------------------------------------------------------------------------------------

-- Complain if script is sourced in psql, rather than via `CREATE EXTENSION`
\echo Use "CREATE EXTENSION pg_xenophile" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

comment
    on extension pg_xenophile
    is $markdown$
# `pg_xenophile` PostgreSQL extension

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

<?pg-readme-reference?>

<?pg-readme-colophon?>

$markdown$;

--------------------------------------------------------------------------------------------------------------

comment
    on schema xeno
    is $markdown$
The `xeno` schema belongs to the `pg_xenophile` extension.

Postgres (as of Pg 15) doesn't allow one to specify a _default_ schema, and do
something like `schema = 'xeno'` combined with `relocatable = true` in the
`.control` file.  Therefore I decided to bluntly force the `xeno` schema name
upon you, even though you might have very well (and justifyingly so) preferred
something like `i18n`.
$markdown$;

--------------------------------------------------------------------------------------------------------------

-- Allow `readme.pg_extension_readme()` for other extensions to link to objects in this extension.
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

comment
    on function pg_xenophile_readme()
    is $markdown$
Generates a README in Markdown format using the amazing power of the
`pg_readme` extension.  Temporarily installs `pg_readme` if it is not already
installed in the current database.
$markdown$;

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
        ,'gpl_3'
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
                "file": "pg_xenophile--0.3.0.sql",
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

create domain currency_code
    as text
    check (value ~ '^[A-Z]{3}$');

comment on domain currency_code
    is $markdown$
Using this domain instead of its underlying `text` type ensures that only
uppercase, 3-letter currency codes are allowed.  It does _not_ enforce that the
`currency_code` exists in the `currency` table.
$markdown$;

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

comment
    on table currency
    is $markdown$
The `currency` table contains the currencies known to `pg_xenophile`.
$markdown$;

comment
    on column currency.currency_code
    is $markdown$
`currency_code` is a 3-letter ISO 4217 currency code.
$markdown$;

comment
    on column currency.currency_code_num
    is $markdown$
`currency_code` is the numeric 3-digit ISO 4217 currency code.
$markdown$;

comment
    on column currency.currency_belongs_to_pg_xenophile
    is $markdown$
Does this currency belong to the `pg_xenophile` extension or not.

If `NOT currency_belongs_to_pg_xenophile`, it is considered a custom currency
inserted by the extension user rather than the extension developer.  Instead
(or in addition) of adding such custom rows, please feel free to submit patches
with all the currencies that you wish for `pg_xenophile` to embrace.
$markdown$;

select pg_catalog.pg_extension_config_dump(
    'currency',
    'WHERE NOT currency_belongs_to_pg_xenophile'
);

insert into currency
    (currency_code, currency_code_num, currency_symbol, currency_belongs_to_pg_xenophile)
values
    ('EUR', '978', '€', true),
    ('GBP', '826', '£', true),
    ('USD', '840', '$', true);

--------------------------------------------------------------------------------------------------------------

create domain country_code_alpha2
    as text
    check (value ~ '^[A-Z]{2}$');

comment on domain country_code_alpha2
    is $markdown$
Using this domain instead of its underlying `text` type ensures that only
2-letter, uppercase country codes are allowed.
$markdown$;

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

comment on table country
    is 'The ISO 3166-1 alpha-2, alpha3 and numeric country codes, as well as some auxillary information.';

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

--------------------------------------------------------------------------------------------------------------

create table lang (
    lang_code lang_code_alpha2
        primary key
    ,lang_belongs_to_pg_xenophile boolean
        not null
        default false
);

comment
    on column lang.lang_code
    is 'ISO 639-1 two-letter (lowercase) language code.';

--------------------------------------------------------------------------------------------------------------

create function pg_xenophile_base_lang_code()
    returns lang_code_alpha2
    stable
    leakproof
    set pg_readme.include_this_routine_definition to true
    set search_path from current
    language sql
    return coalesce(
        pg_catalog.current_setting('app_settings.i18n.base_lang_code', true),
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
        -- TODO: Get the preferred (AND supported) language code from the header
        pg_catalog.current_setting('app_settings.i18n.user_lang_code', true),
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
    ,l10n_table_belongs_to_pg_xenophile boolean
        not null
        default false
);

comment
    on table l10n_table
    is $markdown$
The `l10n_table` table is meant to keep track and manage all the
`_l10n`-suffixed tables.  By inserting a row in this table, with just the
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
types](https://www.postgresql.org/docs/current/datatype-oid.html).  The reason
is that, even though `pg_dump` has the ability to dump OIDs, tables belonging
to extensions are not dumped at all, except for any part exempted from this
using the `pg_catalog.pg_extension_config_dump()` function.  For `l10n_table`,
only the columns for which `l10n_table_belongs_to_pg_xenophile = false` are
included in the dump.
$markdown$;

comment
    on column l10n_table.l10n_table_belongs_to_pg_xenophile
    is $markdown$
If this is `true`, then the created localization (l10n) _table_ will be managed
(and thus recreated after a restore) by the `pg_xenophile` extension.  That is
_not_ the same as saying that the l10n table's rows will belong to
`pg_xenophile`.  To determine the latter, a `l10n_columns_belong_to_pg_xenophile`
column will be added to the l10n table if `create_l10n_table()` was called with
the `will_belong_to_pg_xenophile$ => true` argument.

Only developers of this extension need to worry about these booleans.  For
users, the default of `false` assures that they will lose none of their precious
data.
$markdown$;

select pg_catalog.pg_extension_config_dump(
    'l10n_table',
    'WHERE NOT l10n_table_belongs_to_pg_xenophile'
);

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

create function l10n_table__track_alter_table_events()
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

create event trigger l10n_table__track_drop_table_events
    on sql_drop
    when TAG in ('DROP TABLE')
    execute function l10n_table__track_drop_table_events();

--------------------------------------------------------------------------------------------------------------

create function l10n_table__maintain_l10n_objects()
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
                || case when NEW.l10n_table_belongs_to_pg_xenophile then '
                ,l10n_columns_belong_to_pg_xenophile boolean
                    NOT NULL
                    DEFAULT FALSE' else '' end || '
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

        if NEW.l10n_table_belongs_to_pg_xenophile then
            perform pg_catalog.pg_extension_config_dump(
                _l10n_table_path,
                'WHERE NOT l10n_columns_belong_to_pg_xenophile'
            );
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
                array_agg(NEW.l10n_table_name || '_' || required_lang_code)
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

comment
    on function l10n_table__maintain_l10n_objects()
    is $markdown$
The `l10n_table__maintain_l10n_objects()` trigger function is meant to actuate
changes to the `l10_table` to the actual l10n tables and views tracked by that
meta table.
$markdown$;

create trigger maintain_l10n_objects
    before insert or update or delete
    on l10n_table
    for each row
    execute function l10n_table__maintain_l10n_objects();

--------------------------------------------------------------------------------------------------------------

create function updatable_l10_view()
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
    _l10n_columns := array(
        select  columns.column_name
        from    information_schema.columns
        where   columns.table_schema = _schema_name
                and columns.table_name = _l10n_table
                and columns.column_name != 'l10n_lang_code'
    );

    if tg_op = 'INSERT' then
        execute 'INSERT INTO ' || _base_table_path || '(
                ' || array_to_string(_base_columns_for_upsert, ', ') || '
                ) VALUES (
                ' || (
                        select string_agg('$1.' || quote_ident(col), ', ')
                        from unnest(_base_columns_for_upsert) as col
                    ) || '
                ) RETURNING *'
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
                        select quote_ident(col) || ' = $1.' || quote_ident(col)
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
    end if;
    if tg_op = 'INSERT' or (tg_op = 'UPDATE' and OLD.l10n_lang_code is null) then
        execute 'INSERT INTO ' || _l10n_table_path || '(
                l10n_lang_code
                ,' || array_to_string(_l10n_columns, ', ') || '
                ) VALUES (
                ' || quote_literal(_target_lang_code) || '
                ,' || (
                        select string_agg('$1.' || quote_ident(col), ', ')
                        from unnest(_l10n_columns) as col
                    ) || '
                ) RETURNING *'
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
        raise notice '%', ('UPDATE ' || _l10n_table_path || '
                SET
                ' || (
                        select string_agg(quote_ident(col) || ' = $1.' || quote_ident(col), ', ')
                        from unnest(_l10n_columns) as col
                ) || '
                WHERE ' || quote_ident(_pk_column) || ' = $2.' || quote_ident(_pk_column)
                    || ' AND l10n_lang_code = ' || quote_literal(_target_lang_code)
                || ' RETURNING *');
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
        execute 'DELETE FROM ' || _base_table_path || ' WHERE '
                || quote_ident(_pk_column) || ' = $1.' || quote_ident(_pk_column)
            using OLD;
        -- The `ON DELETE CASCADE` on the FK from the l10n table will do the rest.

        return OLD;
    else
        return NEW;
    end if;
end;
$$;

--------------------------------------------------------------------------------------------------------------

create procedure create_l10n_view(
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
            || ' FOR EACH ROW EXECUTE FUNCTION updatable_l10_view('
                || quote_literal(table_schema$)
                || ', ' || quote_literal(base_table$)
                || ', ' || quote_literal(l10n_table$)
                || ', ' || quote_literal(_fk_details.foreign_column_name)
            || ')';
end;
$$;

--------------------------------------------------------------------------------------------------------------

create procedure test__l10n_table()
    set search_path from current
    set pg_readme.include_this_routine_definition to true
    language plpgsql
    as $$
declare
    _row record;
    _nl_expected_1 record;
    _nl_expected_2 record;
    _en_expected_1 record;
    _l10n_table l10n_table;
begin
    create table test_tbl_a (
        id bigint
            primary key
            generated always as identity
        ,universal_blergh text
    );

    insert into l10n_table (base_table_name, l10n_column_definitions, base_lang_code, target_lang_codes)
    values (
        'test_tbl_a'
        ,array['name TEXT NOT NULL', 'description TEXT NOT NULL']
        ,'nl'::lang_code_alpha2  -- Apologies for the Dutch East India Company mentality.
        ,array['en', 'fr']::lang_code_alpha2[]
    );

    assert array['test_tbl_a_l10n_en', 'test_tbl_a_l10n_fr', 'test_tbl_a_l10n_nl']::name[] = (
        select      array_agg(views.table_name order by views.table_name)::name[]
        from        information_schema.views
        where       views.table_schema = current_schema
                    and views.table_name like 'test\_tbl\_a\_l10n\___'
    );

    _nl_expected_1 := row(
        1, 'AX-UNI', 'nl', 'Bijl Universiteit', 'De trainingsleider in bijlonderhoud en gebruik'
    )::test_tbl_a_l10n_nl;

    insert into test_tbl_a_l10n_nl (universal_blergh, "name", "description")
        values (_nl_expected_1.universal_blergh, _nl_expected_1."name", _nl_expected_1."description")
        returning *
        into _row;

    assert _row = _nl_expected_1;

    assert _nl_expected_1 = (select row(tbl.*)::test_tbl_a_l10n_nl from test_tbl_a_l10n_nl as tbl);

    _en_expected_1 := row(
        1, 'AX-UNI', 'en', 'Axe University', 'The leader in axe maintenance and usage training'
    )::test_tbl_a_l10n_en;

    update test_tbl_a_l10n_en
        set "name" = _en_expected_1."name"
            ,"description" = _en_expected_1."description"
        where
            id = _nl_expected_1.id
        returning
            *
        into
            _row;

    assert _row = _en_expected_1,
        format('%s ≠ %s', _row, _en_expected_1);

    assert _en_expected_1 = (select row(tbl.*)::test_tbl_a_l10n_en from test_tbl_a_l10n_en as tbl);

    _nl_expected_2 := row(
        2, 'PO-UNI', 'nl', 'Poep-Universiteit', 'De Beste Plek om Te Leren Legen'
    )::test_tbl_a_l10n_nl;

    insert into test_tbl_a_l10n_nl (universal_blergh, "name", "description")
        values (_nl_expected_2.universal_blergh, _nl_expected_2."name", _nl_expected_2."description")
        returning *
        into _row;
    assert _row = _nl_expected_2;

    delete from test_tbl_a_l10n_fr where id = 1;
    assert found;

    <<trigger_alter_table_event>>
    begin
        alter table test_tbl_a_l10n
            add description2 text;

        update test_tbl_a_l10n
            set description2 = 'Something to satisfy NOT NULL';  -- Because we want to make it NOT NULL.

        alter table test_tbl_a_l10n
            alter column description2 set not null;

        select * into _l10n_table from l10n_table where base_table_name = 'test_tbl_a';

        assert _l10n_table.l10n_column_definitions[3] = 'description2 text NOT NULL',
            'The `l10n_table__track_alter_table_events` event trigger should have updated the list of l10n'
            ' columns.';

        assert exists(
                select
                from    pg_attribute
                where   attrelid = 'test_tbl_a_l10n_fr'::regclass
                        and attname = 'description2'
            ), 'The `description2` column should have been added to the view.';

        alter table test_tbl_a_l10n
            drop column description2
            cascade;

        select * into _l10n_table from l10n_table where base_table_name = 'test_tbl_a';

        assert array_length(_l10n_table.l10n_column_definitions, 1) = 2,
            'The dropped column should have been removed from the `l10n_table` meta table.';

        assert not exists(
                select
                from    pg_attribute
                where   attrelid = 'test_tbl_a_l10n_nl'::regclass
                        and attname = 'description2'
            ), 'The `description2` column should have disappeared from the views.';

        alter table test_tbl_a
            add non_l10n_col int
                not null
                default 6;

        select * into _l10n_table from l10n_table where base_table_name = 'test_tbl_a';

        assert _l10n_table.base_column_definitions[3] = 'non_l10n_col integer NOT NULL DEFAULT 6',
            'The `l10n_table__track_alter_table_events` event trigger should have updated the list of base'
            ' columns.';

        assert (select non_l10n_col from test_tbl_a_l10n_nl where id = 2) = 6;

        alter table test_tbl_a
            drop column non_l10n_col
            cascade;

        assert not exists(
                select
                from    pg_attribute
                where   attrelid = 'test_tbl_a_l10n_nl'::regclass
                        and attname = 'non_l10n_col'
            ), 'The `non_l10n_col` column should have disappeared from the views.';

        <<drop_base_table>>
        begin
            drop table test_tbl_a cascade;

            assert not exists (select from l10n_table where base_table_name = 'test_tbl_a');

            raise transaction_rollback;  -- I could have used any error code, but this one seemed to fit best.
        exception
            when transaction_rollback then
        end drop_base_table;
    end trigger_alter_table_event;

    delete from l10n_table where base_table_regclass = 'test_tbl_a'::regclass;

    raise transaction_rollback;  -- I could have used any error code, but this one seemed to fit best.
exception
    when transaction_rollback then
end;
$$;

--------------------------------------------------------------------------------------------------------------

insert into l10n_table (
    base_table_name
    ,l10n_column_definitions
    ,base_lang_code, target_lang_codes
    ,l10n_table_belongs_to_pg_xenophile
) values (
    'lang'
    ,array['name TEXT NOT NULL']
    ,'en'::lang_code_alpha2
    ,array[]::lang_code_alpha2[]
    ,true
);

insert into lang_l10n_en
    (lang_code, "name", lang_belongs_to_pg_xenophile, l10n_columns_belong_to_pg_xenophile)
values
    ('en', 'English', true, true),
    ('fr', 'French', true, true),
    ('nl', 'Dutch', true, true),
    ('pt', 'Portuguese', true, true);

--------------------------------------------------------------------------------------------------------------

insert into l10n_table (
    base_table_name
    ,l10n_column_definitions
    ,base_lang_code, target_lang_codes
    ,l10n_table_belongs_to_pg_xenophile
) values (
    'country'::name
    ,array['name TEXT NOT NULL']
    ,'en'::lang_code_alpha2
    ,array[]::lang_code_alpha2[]
    ,true
);

-- Adapted from https://gist.github.com/ereli/0c94ec74a1807aaa895b912766556cc2 on 2022-06-13
insert into country_l10n_en (
    country_code, "name", country_code_alpha3, country_code_num, calling_code, currency_code,
    country_belongs_to_pg_xenophile, l10n_columns_belong_to_pg_xenophile
) values
    ('AF', 'Afghanistan', 'AFG', '004', '093', 'EUR', true, true),
    ('AL', 'Albania', 'ALB', '008', '355', 'EUR', true, true),
    ('DZ', 'Algeria', 'DZA', '012', '213', 'EUR', true, true),
    ('AS', 'American Samoa', 'ASM', '016', 1684, 'EUR', true, true),
    ('AD', 'Andorra', 'AND', '020', '376', 'EUR', true, true),
    ('AO', 'Angola', 'AGO', '024', '244', 'EUR', true, true),
    ('AI', 'Anguilla', 'AIA', '660', 1264, 'EUR', true, true),
    ('AQ', 'Antarctica', 'ATA', '010', 0, 'EUR', true, true),
    ('AG', 'Antigua and Barbuda', 'ATG', '028', 1268, 'EUR', true, true),
    ('AR', 'Argentina', 'ARG', '032', 54, 'EUR', true, true),
    ('AM', 'Armenia', 'ARM', '051', 374, 'EUR', true, true),
    ('AW', 'Aruba', 'ABW', '533', 297, 'EUR', true, true),
    ('AU', 'Australia', 'AUS', '036', 61, 'EUR', true, true),
    ('AT', 'Austria', 'AUT', '040', 43, 'EUR', true, true),
    ('AZ', 'Azerbaijan', 'AZE', '031', 994, 'EUR', true, true),
    ('BS', 'Bahamas', 'BHS', '044', 1242, 'EUR', true, true),
    ('BH', 'Bahrain', 'BHR', '048', 973, 'EUR', true, true),
    ('BD', 'Bangladesh', 'BGD', '050', 880, 'EUR', true, true),
    ('BB', 'Barbados', 'BRB', '052', 1246, 'EUR', true, true),
    ('BY', 'Belarus', 'BLR', '112', 375, 'EUR', true, true),
    ('BE', 'Belgium', 'BEL', '056', 32, 'EUR', true, true),
    ('BZ', 'Belize', 'BLZ', '084', 501, 'EUR', true, true),
    ('BJ', 'Benin', 'BEN', '204', 229, 'EUR', true, true),
    ('BM', 'Bermuda', 'BMU', '060', 1441, 'EUR', true, true),
    ('BT', 'Bhutan', 'BTN', '064', 975, 'EUR', true, true),
    ('BO', 'Bolivia', 'BOL', '068', 591, 'EUR', true, true),
    ('BA', 'Bosnia and Herzegovina', 'BIH', '070', 387, 'EUR', true, true),
    ('BW', 'Botswana', 'BWA', '072', 267, 'EUR', true, true),
    ('BV', 'Bouvet Island', 'BVT', '074', 0, 'EUR', true, true),
    ('BR', 'Brazil', 'BRA', '076', 55, 'EUR', true, true),
    ('IO', 'British Indian Ocean Territory', 'IOT', '086', 246, 'EUR', true, true),
    ('BN', 'Brunei Darussalam', 'BRN', '096', 673, 'EUR', true, true),
    ('BG', 'Bulgaria', 'BGR', '100', 359, 'EUR', true, true),
    ('BF', 'Burkina Faso', 'BFA', '854', 226, 'EUR', true, true),
    ('BI', 'Burundi', 'BDI', '108', 257, 'EUR', true, true),
    ('KH', 'Cambodia', 'KHM', '116', 855, 'EUR', true, true),
    ('CM', 'Cameroon', 'CMR', '120', 237, 'EUR', true, true),
    ('CA', 'Canada', 'CAN', '124', 1, 'EUR', true, true),
    ('CV', 'Cape Verde', 'CPV', '132', 238, 'EUR', true, true),
    ('KY', 'Cayman Islands', 'CYM', '136', 1345, 'EUR', true, true),
    ('CF', 'Central African Republic', 'CAF', '140', 236, 'EUR', true, true),
    ('TD', 'Chad', 'TCD', '148', 235, 'EUR', true, true),
    ('CL', 'Chile', 'CHL', '152', 56, 'EUR', true, true),
    ('CN', 'China', 'CHN', '156', 86, 'EUR', true, true),
    ('CX', 'Christmas Island', 'CXR', '162', 61, 'EUR', true, true),
    --('CC', 'Cocos (Keeling) Islands', NULL, NULL, 672, 'EUR', true, true),
    ('CO', 'Colombia', 'COL', '170', 57, 'EUR', true, true),
    ('KM', 'Comoros', 'COM', '174', 269, 'EUR', true, true),
    ('CG', 'Congo', 'COG', '178', 242, 'EUR', true, true),
    ('CD', 'Congo, the Democratic Republic of the', 'COD', '180', 242, 'EUR', true, true),
    ('CK', 'Cook Islands', 'COK', '184', 682, 'EUR', true, true),
    ('CR', 'Costa Rica', 'CRI', '188', 506, 'EUR', true, true),
    ('CI', 'Cote D''Ivoire', 'CIV', '384', 225, 'EUR', true, true),
    ('HR', 'Croatia', 'HRV', '191', 385, 'EUR', true, true),
    ('CU', 'Cuba', 'CUB', '192', 53, 'EUR', true, true),
    ('CY', 'Cyprus', 'CYP', '196', 357, 'EUR', true, true),
    ('CZ', 'Czech Republic', 'CZE', '203', 420, 'EUR', true, true),
    ('DK', 'Denmark', 'DNK', '208', 45, 'EUR', true, true),
    ('DJ', 'Djibouti', 'DJI', '262', 253, 'EUR', true, true),
    ('DM', 'Dominica', 'DMA', '212', 1767, 'EUR', true, true),
    ('DO', 'Dominican Republic', 'DOM', '214', 1, 'EUR', true, true),
    ('EC', 'Ecuador', 'ECU', '218', 593, 'EUR', true, true),
    ('EG', 'Egypt', 'EGY', '818', 20, 'EUR', true, true),
    ('SV', 'El Salvador', 'SLV', '222', 503, 'EUR', true, true),
    ('GQ', 'Equatorial Guinea', 'GNQ', '226', 240, 'EUR', true, true),
    ('ER', 'Eritrea', 'ERI', '232', 291, 'EUR', true, true),
    ('EE', 'Estonia', 'EST', '233', 372, 'EUR', true, true),
    ('ET', 'Ethiopia', 'ETH', '231', 251, 'EUR', true, true),
    ('FK', 'Falkland Islands (Malvinas)', 'FLK', '238', 500, 'EUR', true, true),
    ('FO', 'Faroe Islands', 'FRO', '234', 298, 'EUR', true, true),
    ('FJ', 'Fiji', 'FJI', '242', 679, 'EUR', true, true),
    ('FI', 'Finland', 'FIN', '246', 358, 'EUR', true, true),
    ('FR', 'France', 'FRA', '250', 33, 'EUR', true, true),
    ('GF', 'French Guiana', 'GUF', '254', 594, 'EUR', true, true),
    ('PF', 'French Polynesia', 'PYF', '258', 689, 'EUR', true, true),
    ('TF', 'French Southern Territories', 'ATF', '260', 0, 'EUR', true, true),
    ('GA', 'Gabon', 'GAB', '266', 241, 'EUR', true, true),
    ('GM', 'Gambia', 'GMB', '270', 220, 'EUR', true, true),
    ('GE', 'Georgia', 'GEO', '268', 995, 'EUR', true, true),
    ('DE', 'Germany', 'DEU', '276', 49, 'EUR', true, true),
    ('GH', 'Ghana', 'GHA', '288', 233, 'EUR', true, true),
    ('GI', 'Gibraltar', 'GIB', '292', 350, 'EUR', true, true),
    ('GR', 'Greece', 'GRC', '300', 30, 'EUR', true, true),
    ('GL', 'Greenland', 'GRL', '304', 299, 'EUR', true, true),
    ('GD', 'Grenada', 'GRD', '308', 1473, 'EUR', true, true),
    ('GP', 'Guadeloupe', 'GLP', '312', 590, 'EUR', true, true),
    ('GU', 'Guam', 'GUM', '316', 1671, 'EUR', true, true),
    ('GT', 'Guatemala', 'GTM', '320', 502, 'EUR', true, true),
    ('GN', 'Guinea', 'GIN', '324', 224, 'EUR', true, true),
    ('GW', 'Guinea-Bissau', 'GNB', '624', 245, 'EUR', true, true),
    ('GY', 'Guyana', 'GUY', '328', 592, 'EUR', true, true),
    ('HT', 'Haiti', 'HTI', '332', 509, 'EUR', true, true),
    ('HM', 'Heard Island and Mcdonald Islands', 'HMD', '334', 0, 'EUR', true, true),
    ('VA', 'Holy See (Vatican City State)', 'VAT', '336', 39, 'EUR', true, true),
    ('HN', 'Honduras', 'HND', '340', 504, 'EUR', true, true),
    ('HK', 'Hong Kong', 'HKG', '344', 852, 'EUR', true, true),
    ('HU', 'Hungary', 'HUN', '348', 36, 'EUR', true, true),
    ('IS', 'Iceland', 'ISL', '352', 354, 'EUR', true, true),
    ('IN', 'India', 'IND', '356', 91, 'EUR', true, true),
    ('ID', 'Indonesia', 'IDN', '360', 62, 'EUR', true, true),
    ('IR', 'Iran, Islamic Republic of', 'IRN', '364', 98, 'EUR', true, true),
    ('IQ', 'Iraq', 'IRQ', '368', 964, 'EUR', true, true),
    ('IE', 'Ireland', 'IRL', '372', 353, 'EUR', true, true),
    ('IL', 'Israel', 'ISR', '376', 972, 'EUR', true, true),
    ('IT', 'Italy', 'ITA', '380', 39, 'EUR', true, true),
    ('JM', 'Jamaica', 'JAM', '388', 1876, 'EUR', true, true),
    ('JP', 'Japan', 'JPN', '392', 81, 'EUR', true, true),
    ('JO', 'Jordan', 'JOR', '400', 962, 'EUR', true, true),
    ('KZ', 'Kazakhstan', 'KAZ', '398', 7, 'EUR', true, true),
    ('KE', 'Kenya', 'KEN', '404', 254, 'EUR', true, true),
    ('KI', 'Kiribati', 'KIR', '296', 686, 'EUR', true, true),
    ('KP', 'Korea, Democratic People''s Republic of', 'PRK', '408', 850, 'EUR', true, true),
    ('KR', 'Korea, Republic of', 'KOR', '410', 82, 'EUR', true, true),
    ('KW', 'Kuwait', 'KWT', '414', 965, 'EUR', true, true),
    ('KG', 'Kyrgyzstan', 'KGZ', '417', 996, 'EUR', true, true),
    ('LA', 'Lao People''s Democratic Republic', 'LAO', '418', 856, 'EUR', true, true),
    ('LV', 'Latvia', 'LVA', '428', 371, 'EUR', true, true),
    ('LB', 'Lebanon', 'LBN', '422', 961, 'EUR', true, true),
    ('LS', 'Lesotho', 'LSO', '426', 266, 'EUR', true, true),
    ('LR', 'Liberia', 'LBR', '430', 231, 'EUR', true, true),
    ('LY', 'Libyan Arab Jamahiriya', 'LBY', '434', 218, 'EUR', true, true),
    ('LI', 'Liechtenstein', 'LIE', '438', 423, 'EUR', true, true),
    ('LT', 'Lithuania', 'LTU', '440', 370, 'EUR', true, true),
    ('LU', 'Luxembourg', 'LUX', '442', 352, 'EUR', true, true),
    ('MO', 'Macao', 'MAC', '446', 853, 'EUR', true, true),
    ('MK', 'North Macedonia', 'MKD', '807', 389, 'EUR', true, true),
    ('MG', 'Madagascar', 'MDG', '450', 261, 'EUR', true, true),
    ('MW', 'Malawi', 'MWI', '454', 265, 'EUR', true, true),
    ('MY', 'Malaysia', 'MYS', '458', 60, 'EUR', true, true),
    ('MV', 'Maldives', 'MDV', '462', 960, 'EUR', true, true),
    ('ML', 'Mali', 'MLI', '466', 223, 'EUR', true, true),
    ('MT', 'Malta', 'MLT', '470', 356, 'EUR', true, true),
    ('MH', 'Marshall Islands', 'MHL', '584', 692, 'EUR', true, true),
    ('MQ', 'Martinique', 'MTQ', '474', 596, 'EUR', true, true),
    ('MR', 'Mauritania', 'MRT', '478', 222, 'EUR', true, true),
    ('MU', 'Mauritius', 'MUS', '480', 230, 'EUR', true, true),
    ('YT', 'Mayotte', 'MYT', '175', 269, 'EUR', true, true),
    ('MX', 'Mexico', 'MEX', '484', 52, 'EUR', true, true),
    ('FM', 'Micronesia, Federated States of', 'FSM', '583', 691, 'EUR', true, true),
    ('MD', 'Moldova, Republic of', 'MDA', '498', 373, 'EUR', true, true),
    ('MC', 'Monaco', 'MCO', '492', 377, 'EUR', true, true),
    ('MN', 'Mongolia', 'MNG', '496', 976, 'EUR', true, true),
    ('MS', 'Montserrat', 'MSR', '500', 1664, 'EUR', true, true),
    ('MA', 'Morocco', 'MAR', '504', 212, 'EUR', true, true),
    ('MZ', 'Mozambique', 'MOZ', '508', 258, 'EUR', true, true),
    ('MM', 'Myanmar', 'MMR', '104', 95, 'EUR', true, true),
    ('NA', 'Namibia', 'NAM', '516', 264, 'EUR', true, true),
    ('NR', 'Nauru', 'NRU', '520', 674, 'EUR', true, true),
    ('NP', 'Nepal', 'NPL', '524', 977, 'EUR', true, true),
    ('NL', 'Netherlands', 'NLD', '528', 31, 'EUR', true, true),
    ('AN', 'Netherlands Antilles', 'ANT', '530', 599, 'EUR', true, true),
    ('NC', 'New Caledonia', 'NCL', '540', 687, 'EUR', true, true),
    ('NZ', 'New Zealand', 'NZL', '554', 64, 'EUR', true, true),
    ('NI', 'Nicaragua', 'NIC', '558', 505, 'EUR', true, true),
    ('NE', 'Niger', 'NER', '562', 227, 'EUR', true, true),
    ('NG', 'Nigeria', 'NGA', '566', 234, 'EUR', true, true),
    ('NU', 'Niue', 'NIU', '570', 683, 'EUR', true, true),
    ('NF', 'Norfolk Island', 'NFK', '574', 672, 'EUR', true, true),
    ('MP', 'Northern Mariana Islands', 'MNP', '580', 1670, 'EUR', true, true),
    ('NO', 'Norway', 'NOR', '578', 47, 'EUR', true, true),
    ('OM', 'Oman', 'OMN', '512', 968, 'EUR', true, true),
    ('PK', 'Pakistan', 'PAK', '586', 92, 'EUR', true, true),
    ('PW', 'Palau', 'PLW', '585', 680, 'EUR', true, true),
    --('PS', 'Palestinian Territory, Occupied', NULL, NULL, 970, 'EUR', true, true),
    ('PA', 'Panama', 'PAN', '591', 507, 'EUR', true, true),
    ('PG', 'Papua New Guinea', 'PNG', '598', 675, 'EUR', true, true),
    ('PY', 'Paraguay', 'PRY', '600', 595, 'EUR', true, true),
    ('PE', 'Peru', 'PER', '604', 51, 'EUR', true, true),
    ('PH', 'Philippines', 'PHL', '608', 63, 'EUR', true, true),
    ('PN', 'Pitcairn', 'PCN', '612', 0, 'EUR', true, true),
    ('PL', 'Poland', 'POL', '616', 48, 'EUR', true, true),
    ('PT', 'Portugal', 'PRT', '620', 351, 'EUR', true, true),
    ('PR', 'Puerto Rico', 'PRI', '630', 1787, 'EUR', true, true),
    ('QA', 'Qatar', 'QAT', '634', 974, 'EUR', true, true),
    ('RE', 'Reunion', 'REU', '638', 262, 'EUR', true, true),
    ('RO', 'Romania', 'ROU', '642', 40, 'EUR', true, true),
    ('RU', 'Russian Federation', 'RUS', '643', 7, 'EUR', true, true),
    ('RW', 'Rwanda', 'RWA', '646', 250, 'EUR', true, true),
    ('SH', 'Saint Helena', 'SHN', '654', 290, 'EUR', true, true),
    ('KN', 'Saint Kitts and Nevis', 'KNA', '659', 1869, 'EUR', true, true),
    ('LC', 'Saint Lucia', 'LCA', '662', 1758, 'EUR', true, true),
    ('PM', 'Saint Pierre and Miquelon', 'SPM', '666', 508, 'EUR', true, true),
    ('VC', 'Saint Vincent and the Grenadines', 'VCT', '670', 1784, 'EUR', true, true),
    ('WS', 'Samoa', 'WSM', '882', 684, 'EUR', true, true),
    ('SM', 'San Marino', 'SMR', '674', 378, 'EUR', true, true),
    ('ST', 'Sao Tome and Principe', 'STP', '678', 239, 'EUR', true, true),
    ('SA', 'Saudi Arabia', 'SAU', '682', 966, 'EUR', true, true),
    ('SN', 'Senegal', 'SEN', '686', 221, 'EUR', true, true),
    ('RS', 'Serbia', 'SRB', '688', 381, 'EUR', true, true),
    ('SC', 'Seychelles', 'SYC', '690', 248, 'EUR', true, true),
    ('SL', 'Sierra Leone', 'SLE', '694', 232, 'EUR', true, true),
    ('SG', 'Singapore', 'SGP', '702', 65, 'EUR', true, true),
    ('SK', 'Slovakia', 'SVK', '703', 421, 'EUR', true, true),
    ('SI', 'Slovenia', 'SVN', '705', 386, 'EUR', true, true),
    ('SB', 'Solomon Islands', 'SLB', '090', 677, 'EUR', true, true),
    ('SO', 'Somalia', 'SOM', '706', 252, 'EUR', true, true),
    ('ZA', 'South Africa', 'ZAF', '710', 27, 'EUR', true, true),
    ('GS', 'South Georgia and the South Sandwich Islands', 'SGS', '239', 0, 'EUR', true, true),
    ('ES', 'Spain', 'ESP', '724', 34, 'EUR', true, true),
    ('LK', 'Sri Lanka', 'LKA', '144', 94, 'EUR', true, true),
    ('SD', 'Sudan', 'SDN', '736', 249, 'EUR', true, true),
    ('SR', 'Suriname', 'SUR', '740', 597, 'EUR', true, true),
    ('SJ', 'Svalbard and Jan Mayen', 'SJM', '744', 47, 'EUR', true, true),
    ('SZ', 'Swaziland', 'SWZ', '748', 268, 'EUR', true, true),
    ('SE', 'Sweden', 'SWE', '752', 46, 'EUR', true, true),
    ('CH', 'Switzerland', 'CHE', '756', 41, 'EUR', true, true),
    ('SY', 'Syrian Arab Republic', 'SYR', '760', 963, 'EUR', true, true),
    ('TW', 'Taiwan, Province of China', 'TWN', '158', 886, 'EUR', true, true),
    ('TJ', 'Tajikistan', 'TJK', '762', 992, 'EUR', true, true),
    ('TZ', 'Tanzania, United Republic of', 'TZA', '834', 255, 'EUR', true, true),
    ('TH', 'Thailand', 'THA', '764', 66, 'EUR', true, true),
    ('TL', 'Timor-Leste', 'TLS', '626', 670, 'EUR', true, true),
    ('TG', 'Togo', 'TGO', '768', 228, 'EUR', true, true),
    ('TK', 'Tokelau', 'TKL', '772', 690, 'EUR', true, true),
    ('TO', 'Tonga', 'TON', '776', 676, 'EUR', true, true),
    ('TT', 'Trinidad and Tobago', 'TTO', '780', 1868, 'EUR', true, true),
    ('TN', 'Tunisia', 'TUN', '788', 216, 'EUR', true, true),
    ('TR', 'Turkey', 'TUR', '792', 90, 'EUR', true, true),
    ('TM', 'Turkmenistan', 'TKM', '795', 993, 'EUR', true, true),
    ('TC', 'Turks and Caicos Islands', 'TCA', '796', 1649, 'EUR', true, true),
    ('TV', 'Tuvalu', 'TUV', '798', 688, 'EUR', true, true),
    ('UG', 'Uganda', 'UGA', '800', 256, 'EUR', true, true),
    ('UA', 'Ukraine', 'UKR', '804', 380, 'EUR', true, true),
    ('AE', 'United Arab Emirates', 'ARE', '784', 971, 'EUR', true, true),
    ('GB', 'United Kingdom', 'GBR', '826', 44, 'EUR', true, true),
    ('US', 'United States', 'USA', '840', 1, 'EUR', true, true),
    ('UM', 'United States Minor Outlying Islands', 'UMI', '581', 1, 'EUR', true, true),
    ('UY', 'Uruguay', 'URY', '858', 598, 'EUR', true, true),
    ('UZ', 'Uzbekistan', 'UZB', '860', 998, 'EUR', true, true),
    ('VU', 'Vanuatu', 'VUT', '548', 678, 'EUR', true, true),
    ('VE', 'Venezuela', 'VEN', '862', 58, 'EUR', true, true),
    ('VN', 'Viet Nam', 'VNM', '704', 84, 'EUR', true, true),
    ('VG', 'Virgin Islands, British', 'VGB', '092', 1284, 'EUR', true, true),
    ('VI', 'Virgin Islands, U.s.', 'VIR', '850', 1340, 'EUR', true, true),
    ('WF', 'Wallis and Futuna', 'WLF', '876', 681, 'EUR', true, true),
    ('EH', 'Western Sahara', 'ESH', '732', 212, 'EUR', true, true),
    ('YE', 'Yemen', 'YEM', '887', 967, 'EUR', true, true),
    ('ZM', 'Zambia', 'ZMB', '894', 260, 'EUR', true, true),
    ('ZW', 'Zimbabwe', 'ZWE', '716', 263, 'EUR', true, true),
    ('ME', 'Montenegro', 'MNE', '499', 382, 'EUR', true, true),
    ('XK', 'Kosovo', 'XKX', '000', 383, 'EUR', true, true),
    ('AX', 'Aland Islands', 'ALA', '248', '358', 'EUR', true, true),
    ('BQ', 'Bonaire, Sint Eustatius and Saba', 'BES', '535', '599', 'EUR', true, true),
    ('CW', 'Curacao', 'CUW', '531', '599', 'EUR', true, true),
    ('GG', 'Guernsey', 'GGY', '831', '44', 'EUR', true, true),
    ('IM', 'Isle of Man', 'IMN', '833', '44', 'EUR', true, true),
    ('JE', 'Jersey', 'JEY', '832', '44', 'EUR', true, true),
    ('BL', 'Saint Barthelemy', 'BLM', '652', '590', 'EUR', true, true),
    ('MF', 'Saint Martin', 'MAF', '663', '590', 'EUR', true, true),
    ('SX', 'Sint Maarten', 'SXM', '534', '1', 'EUR', true, true),
    ('SS', 'South Sudan', 'SSD', '728', '211', 'EUR', true, true);

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
