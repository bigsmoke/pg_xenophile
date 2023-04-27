-- Complain if script is sourced in psql, rather than via `CREATE EXTENSION`
\echo Use "CREATE EXTENSION pg_xenophile" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

-- Add Spanish as the fourth language, for the benefit of the test case.
insert into lang_l10n_en
    (lang_code, "name", lang_belongs_to_pg_xenophile, l10n_columns_belong_to_pg_xenophile)
values
    ('es', 'Spanish', true, true);

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

--------------------------------------------------------------------------------------------------------------

alter table l10n_table
    add column l10n_table_belongs_to_extension_name name
    ,add column l10n_table_belongs_to_extension_version text;

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

create trigger set_installed_extension_version_from_name
    before insert on l10n_table
    for each row
    when (NEW.l10n_table_belongs_to_extension_name is not null)
    execute function set_installed_extension_version_from_name(
        'l10n_table_belongs_to_extension_name'
        ,'l10n_table_belongs_to_extension_version'
    );

--------------------------------------------------------------------------------------------------------------

-- Rename from `updatable_l10_view` (with missing ‘n’) to `updatable_l10n_view`.
-- (`DROP` happens further down.)
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

-- Adjust to new name (`updatable_l10n_view`) of trigger function.
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

-- Allow other extensions to also own l10n tables.
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

update
    l10n_table
set
    l10n_table_belongs_to_extension_name = 'pg_xenophile'
    ,l10n_table_belongs_to_extension_version = (
        select extversion from pg_catalog.pg_extension where extname = 'pg_xenophile'
    )
where
    l10n_table_belongs_to_pg_xenophile
;

select pg_catalog.pg_extension_config_dump(
    'l10n_table',
    'WHERE l10n_table_belongs_to_extension_name IS NULL'
);

alter table l10n_table
    drop column l10n_table_belongs_to_pg_xenophile;

-- Modify the column for all the existing l10n tables that belong to pg_xenophile.
do $$
declare
    _l10n_table l10n_table;
    _l10n_view regclass;
begin
    for _l10n_table in select * from l10n_table where l10n_table_belongs_to_extension_name is not null
    loop
        execute 'ALTER TABLE ' || _l10n_table.l10n_table_regclass
            || ' ADD COLUMN l10n_columns_belong_to_extension_name name'
            || ' ,ADD COLUMN l10n_columns_belong_to_extension_version text';
        execute 'UPDATE ' || _l10n_table.l10n_table_regclass || ' SET'
            || ' l10n_columns_belong_to_extension_name = ''pg_xenophile'''
            || ' ,l10n_columns_belong_to_extension_version = $1'
            || ' WHERE l10n_columns_belong_to_pg_xenophile'
            using (
                select extversion from pg_catalog.pg_extension where extname = 'pg_xenophile'
            );
        for _l10n_view in
            select
                distinct (
                    quote_ident(_l10n_table.schema_name) || '.'
                    || _l10n_table.l10n_table_name || '_' || lang_code
                )::regclass
            from
                unnest(_l10n_table.target_lang_codes || _l10n_table.base_lang_code) as lang_code
        loop
            execute 'DROP VIEW ' || _l10n_view;  -- Drop views. They will be recreated by the `ALTER TABLE`.
        end loop;
        execute 'ALTER TABLE ' || _l10n_table.l10n_table_regclass
            || ' DROP COLUMN l10n_columns_belong_to_pg_xenophile';
        perform pg_catalog.pg_extension_config_dump(
            _l10n_table.l10n_table_regclass
            ,'WHERE l10n_columns_belong_to_extension_name IS NULL'
        );
        execute 'CREATE TRIGGER set_installed_extension_version_from_name'
            || ' BEFORE INSERT ON ' || _l10n_table.l10n_table_regclass
            || ' FOR EACH ROW'
            || ' WHEN (NEW.l10n_columns_belong_to_extension_name IS NOT NULL)'
            || ' EXECUTE FUNCTION set_installed_extension_version_from_name('
            || '''l10n_columns_belong_to_extension_name'', ''l10n_columns_belong_to_extension_version'')';
    end loop;
end;
$$;

--------------------------------------------------------------------------------------------------------------

drop function updatable_l10_view();

--------------------------------------------------------------------------------------------------------------
