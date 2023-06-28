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

-- New comment.
comment on procedure create_l10n_view is
$md$Create a language code-suffixed view for a given translated table.

The reason that `create_l10n_view()` is a separate routine and not part of the
`l10n_table__maintain_l10n_objects()` trigger function is that you may have a
requirement to _not_ make l10n views for each of a l10n table's target
languages and instead prefer to create temporary views on an as-needed basis
(by passing the `temp$ => true` parameter).
$md$;

--------------------------------------------------------------------------------------------------------------

-- Get current object names as well.
create or replace function l10n_table_with_fresh_ddl(inout l10n_table)
    stable
    parallel safe
    language plpgsql
    as $$
begin
    select
        pg_namespace.nspname
        ,pg_class.relname
    into
        $1.schema_name
        ,$1.base_table_name
    from
        pg_catalog.pg_class
    inner join
        pg_catalog.pg_namespace
        on pg_namespace.oid = pg_class.relnamespace
    where
        pg_class.oid = ($1).base_table_regclass
    ;

    $1.l10n_table_name := (
        select
            pg_class.relname
        from
            pg_catalog.pg_class
        where
            pg_class.oid = ($1).l10n_table_regclass
    );

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

-- New comment
comment on function l10n_table_with_fresh_ddl(l10n_table) is
$md$Return the given `l10n_table` record, refreshed with data from the current schema.
$md$;

--------------------------------------------------------------------------------------------------------------

-- Support base table renames (and automatic l10n table renames).
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
            or NEW.base_table_name != OLD.base_table_name
            or NEW.l10n_table_name != OLD.l10n_table_name
            or NEW.schema_name != OLD.schema_name
        )
    then
        raise integrity_constraint_violation
            using message = 'After the initial `INSERT`, column and constraint definitions, as well as'
                ' table names, should not be altered directly in this table, only via `ALTER TABLE`'
                ' statements, that will propagate' ' via the `l10n_table__track_alter_table_events`'
                ' event trigger.';
            -- NOTE: Feel free to implement support for this if this causes you discomfort.
    elsif coalesce(
            nullif(current_setting('pg_xenophile.in_l10n_table_event_trigger', true), ''),
            'false'
        )::bool
        and tg_op = 'UPDATE'
        and NEW.l10n_table_name != OLD.l10n_table_name
    then
        raise integrity_constraint_violation using
            message = format(
                'You cannot `ALTER %I.%I RENAME TO %I` directly.'
                ,OLD.schema_name, OLD.l10n_table_name, NEW.l10n_table_name
            )
            ,hint = format(
                'To change the name of `%I.%I`, change the name of its base table `%I` instead.'
                ' The `_l10n` table will then be automatically also renamed.'
                ,OLD.schema_name, OLD.l10n_table_name, OLD.base_table_name
            );
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

    if NEW.l10n_table_name != OLD.l10n_table_name then
        raise debug 'Renaming l10n table `%` to `%`.', OLD.l10n_table_regclass, NEW.l10n_table_name;
        execute format('ALTER TABLE %s RENAME TO %I', OLD.l10n_table_regclass, NEW.l10n_table_name);
    end if;

    if NEW.schema_name != OLD.schema_name then
        execute format('ALTER TABLE %s SET SCHEMA TO %I', OLD.l10n_table_regclass, NEW.schema_name);
    end if;

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

-- Support table renames.
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

    if coalesce(
            nullif(current_setting('pg_xenophile.in_l10n_table_row_trigger', true), '')
            ,'false'
        )::bool
    then
        -- We are already responding to a `UPDATE` to the row, so let's not re-`ALTER` the table.
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
        update
            l10n_table
        set
            (
                schema_name
                ,base_table_name
                ,base_column_definitions
            ) =  (
                select
                    schema_name
                    ,base_table_name
                    ,base_column_definitions
                from
                    l10n_table_with_fresh_ddl(l10n_table.*) as fresh
            )
        where
            base_table_regclass = _ddl_command.objid
        ;

        update
            l10n_table
        set
            (
                schema_name
                ,l10n_table_name
                ,l10n_table_constraint_definitions
                ,l10n_column_definitions
            ) =  (
                select
                    schema_name
                    ,l10n_table_name
                    ,l10n_table_constraint_definitions
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

-- Test table renames.
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

        <<l10n_table_rename_attempt>>
        begin
            alter table test_uni_l10n rename to test_university_l10n;
            raise assert_failure using
                message = 'Directly renaming the l10n table should be impossible.';
        exception
            when integrity_constraint_violation then
        end l10n_table_rename_attempt;

        <<base_table_rename>>
        begin
            alter table test_uni rename to test_university;
        end base_table_rename;

        <<drop_base_table>>
        begin
            drop table test_university cascade;

            assert not exists (select from l10n_table where base_table_name = 'test_university');

            raise transaction_rollback;  -- I could have used any error code, but this one seemed to fit best.
        exception
            when transaction_rollback then
        end drop_base_table;
    end trigger_alter_table_events;

    -- DELETE-ing the meta info for our l10n table should cascade cleanly, without crashing.
    delete from l10n_table where base_table_regclass = 'test_university'::regclass;

    assert to_regclass('test_university_l10n') is null,
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
