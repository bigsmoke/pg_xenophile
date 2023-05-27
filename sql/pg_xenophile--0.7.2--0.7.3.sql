-- Complain if script is sourced in `psql`, rather than via `CREATE EXTENSION`.
\echo Use "CREATE EXTENSION pg_xenophile" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

-- Fix type: `app_settings` → `app.settings`
create or replace function pg_xenophile_base_lang_code()
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

-- Fix type: `app_settings` → `app.settings`
create or replace function pg_xenophile_user_lang_code()
    returns lang_code_alpha2
    stable
    leakproof
    set pg_readme.include_this_routine_definition to true
    set search_path from current
    language sql
    return coalesce(
        -- TODO: Get the preferred (AND supported) language code from the header
        pg_catalog.current_setting('app.settings.i18n.user_lang_code', true),
        pg_catalog.current_setting('pg_xenophile.user_lang_code', true),
        regexp_replace(pg_catalog.current_setting('lc_messages'), '^([a-z]{2}).*$', '\1'),
        'en'::text
    )::xeno.lang_code_alpha2;

--------------------------------------------------------------------------------------------------------------
