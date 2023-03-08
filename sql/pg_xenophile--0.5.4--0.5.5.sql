-- Complain if script is sourced in psql, rather than via `CREATE EXTENSION`
\echo Use "CREATE EXTENSION pg_xenophile" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

-- Add redundant target language to test deduplication.
create or replace procedure test__l10n_table()
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
        ,"universal blergh" text
    );

    insert into l10n_table (base_table_name, l10n_column_definitions, base_lang_code, target_lang_codes)
    values (
        'test_tbl_a'
        ,array['name TEXT NOT NULL', '"description (short)" TEXT NOT NULL']
        ,'nl'::lang_code_alpha2  -- Apologies for the Dutch East India Company mentality.
        ,array['en', 'fr', 'nl']::lang_code_alpha2[]
        -- 'nl' is redundantly added to the array of target languages to test deduplication.
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

    insert into test_tbl_a_l10n_nl ("universal blergh", name, "description (short)")
        values (_nl_expected_1."universal blergh", _nl_expected_1.name, _nl_expected_1."description (short)")
        returning *
        into _row;

    assert _row = _nl_expected_1;

    assert _nl_expected_1 = (select row(tbl.*)::test_tbl_a_l10n_nl from test_tbl_a_l10n_nl as tbl);

    _en_expected_1 := row(
        1, 'AX-UNI', 'en', 'Axe University', 'The leader in axe maintenance and usage training'
    )::test_tbl_a_l10n_en;

    update test_tbl_a_l10n_en
        set "name" = _en_expected_1."name"
            ,"description (short)" = _en_expected_1."description (short)"
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

    insert into test_tbl_a_l10n_nl ("universal blergh", name, "description (short)")
        values (_nl_expected_2."universal blergh", _nl_expected_2.name, _nl_expected_2."description (short)")
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

-- Don't crash if the base language is also in the list of target languages.
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
