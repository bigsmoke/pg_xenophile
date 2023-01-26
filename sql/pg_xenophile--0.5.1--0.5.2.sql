-- Complain if script is sourced in psql, rather than via `CREATE EXTENSION`
\echo Use "CREATE EXTENSION pg_xenophile" to load this file. \quit

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
