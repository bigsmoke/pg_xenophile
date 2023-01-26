-- Complain if script is sourced in psql, rather than via `CREATE EXTENSION`
\echo Use "CREATE EXTENSION pg_xenophile" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

-- Add usage information
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

<?pg-readme-reference?>

<?pg-readme-colophon?>

$markdown$;


--------------------------------------------------------------------------------------------------------------

-- Correct starting file.
-- Change licence from AGPL to the PostgreSQL licence.
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
                "file": "pg_xenophile--0.5.0.sql",
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
