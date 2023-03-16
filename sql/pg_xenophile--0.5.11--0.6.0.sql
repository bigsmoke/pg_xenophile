-- Complain if script is sourced in psql, rather than via `CREATE EXTENSION`
\echo Use "CREATE EXTENSION pg_xenophile" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

-- Document new internal setting.
comment on extension pg_xenophile is $md$
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
| `pg_xenophile.pg_restore_seems_active`       | `false`                         |

<?pg-readme-reference?>

<?pg-readme-colophon?>

$md$;

--------------------------------------------------------------------------------------------------------------

create procedure test_dump_restore__l10n_table(test_stage$ text)
    set search_path from current
    set plpgsql.check_asserts to true
    language plpgsql
    as $$
declare
    _en_expected record;
    _nl_expected record;
    _en_actual record;
    _nl_actual record;
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
end;
$$;

comment on procedure test_dump_restore__l10n_table(text) is
$md$This procedure is to be called by the `test_dump_restore.sh` and `test_dump_restore.sql` companion scripts, once before `pg_dump` (with `test_stage$ = 'pre-dump'` argument) and once after `pg_restore` (with the `test_stage$ = 'post-restore'`).
$md$;

--------------------------------------------------------------------------------------------------------------

-- Detect (and propegage) when we're likely restoring a dump.
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

--------------------------------------------------------------------------------------------------------------

-- Don't do anything when `l10n_table__maintain_l10n_objects()` told us we're likely restoring a dump.
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
