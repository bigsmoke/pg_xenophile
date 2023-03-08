-- Complain if script is sourced in psql, rather than via `CREATE EXTENSION`
\echo Use "CREATE EXTENSION pg_xenophile" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

-- Test UPSERT capability of `updatable_l10n_view()` trigger func.
-- Test that `DELETE FROM l10n_table` cascades neatly to the asctual table and views, and such.
-- More and better asserts and failure messages.
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
    _en_expected_2 record;
    _l10n_table l10n_table;
begin
    create table test_tbl (
        id bigint
            primary key
            generated always as identity
        ,"universal blergh" text
    );

    <<with_redundant_target_lang>>
    begin
        -- This tests that the trigger(s) on `l10n_table` only try to create the `_l10n_nl`-suffixed view
        -- only once and doesn't crash.
        insert into l10n_table
            (base_table_name, l10n_column_definitions, base_lang_code, target_lang_codes)
        values (
            'test_tbl'
            ,array['name TEXT NOT NULL', '"description (short)" TEXT NOT NULL']
            ,'nl'::lang_code_alpha2  -- Apologies for the Dutch East India Company mentality.
            ,array['nl']::lang_code_alpha2[]
        );
        raise transaction_rollback;
    exception
        when transaction_rollback then
    end with_redundant_target_lang;

    insert into l10n_table
        (base_table_name, l10n_column_definitions, base_lang_code, target_lang_codes)
    values (
        'test_tbl'
        ,array['name TEXT NOT NULL', '"description (short)" TEXT NOT NULL']
        ,'nl'::lang_code_alpha2  -- Apologies for the Dutch East India Company mentality.
        ,array['en', 'fr']::lang_code_alpha2[]
    );

    assert to_regclass('test_tbl_l10n') is not null,
        'The `_l10n` table should have been created as result of the preceding INSERT.';

    assert array['test_tbl_l10n_en', 'test_tbl_l10n_fr', 'test_tbl_l10n_nl']::name[] = (
            select
                array_agg(views.table_name order by views.table_name)::name[]
            from
                information_schema.views
            where
                views.table_schema = current_schema
                and views.table_name like 'test\_tbl\_l10n\___'
        )
        ,'3 `_l10n_<lang_code>`-suffixed views should have been created, one for the base language'
            || ' and 2 for the target languages.';

    _nl_expected_1 := row(
        1, 'AX-UNI', 'nl', 'Bijl Universiteit', 'De trainingsleider in bijlonderhoud en gebruik'
    )::test_tbl_l10n_nl;

    -- Insert a row via one of the language-specific views:
    insert into test_tbl_l10n_nl
        ("universal blergh", name, "description (short)")
    values
        (_nl_expected_1."universal blergh", _nl_expected_1.name, _nl_expected_1."description (short)")
    returning
        *
    into
        _row
    ;

    assert _row = _nl_expected_1, format('% ≠ %', _row, _nl_expected_1),
        'The `RETURNING` clause did not return the data as inserted.';

    assert _nl_expected_1 = (select row(tbl.*)::test_tbl_l10n_nl from test_tbl_l10n_nl as tbl),
        'The `RETURNING` clause should have returned the same row data as this separate `SELECT`.';

    _en_expected_1 := row(
        1, 'AX-UNI', 'en', 'Axe University', 'The leader in axe maintenance and usage training'
    )::test_tbl_l10n_en;

    update
        test_tbl_l10n_en
    set
        "name" = _en_expected_1."name"
        ,"description (short)" = _en_expected_1."description (short)"
    where
        id = _nl_expected_1.id
    returning
        *
    into
        _row
    ;

    assert _row = _en_expected_1,
        format('%s ≠ %s; the `RETURNING` clause did not return the data as upserted.', _row, _en_expected_1);

    assert _en_expected_1 = (select row(tbl.*)::test_tbl_l10n_en from test_tbl_l10n_en as tbl),
        'The `RETURNING` clause should have returned the same row data as this separate `SELECT`.';

    _nl_expected_2 := row(
        2, 'PO-UNI', 'nl', 'Poep-Universiteit', 'De Beste Plek om Te Leren Legen'
    )::test_tbl_l10n_nl;

    insert into test_tbl_l10n_nl
        ("universal blergh", name, "description (short)")
    values
        (_nl_expected_2."universal blergh", _nl_expected_2.name, _nl_expected_2."description (short)")
    returning
        *
    into
        _row
    ;

    assert _row = _nl_expected_2,
        format('%s ≠ %s', _row, _nl_expected_2);

    _en_expected_2 := row(
        2, 'PO-UNI', 'en', 'Pooversity', 'The Best Place To Empty Yourself'
    )::test_tbl_l10n_nl;

    -- Test that the trigger `test_tbl_l10n_en` does an INSERT instead of an UPDATE if no row for this
    -- PK+lang_code combo exists yet in `test_tbl_l10n`.
    insert into test_tbl_l10n_en
        (id, "universal blergh", name, "description (short)")
    values (
        _en_expected_2.id
        ,_en_expected_2."universal blergh"
        ,_en_expected_2.name
        ,_en_expected_2."description (short)"
    )
    returning
        *
    into
        _row
    ;

    assert _row = _en_expected_2,
        format('%s ≠ %s', _row, _en_expected_2);

    delete from test_tbl_l10n_fr where id = 1;
    assert found;
    assert not exists (select from test_tbl where id 1),
        'The base table record should have been deleted.';
    assert not exists (select from test_tbl_l10n where id = 1 and l10n_lang_code = 'fr'),
        'The l10n record should have been deleted, via the `ON DELETE CASCADE`.';

    <<trigger_alter_table_event>>
    begin
        alter table test_tbl_l10n
            add description2 text;

        update test_tbl_l10n
            set description2 = 'Something to satisfy NOT NULL';  -- Because we want to make it NOT NULL.

        alter table test_tbl_l10n
            alter column description2 set not null;

        select * into _l10n_table from l10n_table where base_table_name = 'test_tbl';

        assert _l10n_table.l10n_column_definitions[3] = 'description2 text NOT NULL',
            'The `l10n_table__track_alter_table_events` event trigger should have updated the list of l10n'
            ' columns.';

        assert exists(
                select
                from    pg_attribute
                where   attrelid = 'test_tbl_l10n_fr'::regclass
                        and attname = 'description2'
            ), 'The `description2` column should have been added to the view.';

        alter table test_tbl_l10n
            drop column description2
            cascade;

        select * into _l10n_table from l10n_table where base_table_name = 'test_tbl';

        assert array_length(_l10n_table.l10n_column_definitions, 1) = 2,
            'The dropped column should have been removed from the `l10n_table` meta table.';

        assert not exists(
                select
                from    pg_attribute
                where   attrelid = 'test_tbl_l10n_nl'::regclass
                        and attname = 'description2'
            ), 'The `description2` column should have disappeared from the views.';

        alter table test_tbl
            add non_l10n_col int
                not null
                default 6;

        select * into _l10n_table from l10n_table where base_table_name = 'test_tbl';

        assert _l10n_table.base_column_definitions[3] = 'non_l10n_col integer NOT NULL DEFAULT 6',
            'The `l10n_table__track_alter_table_events` event trigger should have updated the list of base'
            ' columns.';

        assert (select non_l10n_col from test_tbl_l10n_nl where id = 2) = 6;

        alter table test_tbl
            drop column non_l10n_col
            cascade;

        assert not exists(
                select
                from    pg_attribute
                where   attrelid = 'test_tbl_l10n_nl'::regclass
                        and attname = 'non_l10n_col'
            ), 'The `non_l10n_col` column should have disappeared from the views.';

        <<drop_base_table>>
        begin
            drop table test_tbl cascade;

            assert not exists (select from l10n_table where base_table_name = 'test_tbl');

            raise transaction_rollback;  -- I could have used any error code, but this one seemed to fit best.
        exception
            when transaction_rollback then
        end drop_base_table;
    end trigger_alter_table_event;

    -- DELETE-ing the meta info for our l10n table should cascade cleanly, without crashing.
    delete from l10n_table where base_table_regclass = 'test_tbl'::regclass;

    assert to_regclass('test_tbl_l10n') is null,
        'The actual `_l10n` table should have been removed when deleting the meta row from `l10n_table`.';

    raise transaction_rollback;  -- I could have used any error code, but this one seemed to fit best.
exception
    when transaction_rollback then
end;
$$;

--------------------------------------------------------------------------------------------------------------

-- Make better UPSERT decisions.
create or replace function updatable_l10_view()
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
                ' || (
                        select string_agg(quote_ident(col), ', ')
                        from unnest(_base_columns_for_upsert) as col
                    ) || '
                ) VALUES (
                ' || (
                        select string_agg('$1.' || quote_ident(col), ', ')
                        from unnest(_base_columns_for_upsert) as col
                    ) || '
                )
                ON CONFLICT (' || quote_ident(_pk_column) || ')
                    DO UPDATE SET
                        ' || (
                            select string_agg(quote_ident(col) || ' = $1.' || quote_ident(col), ', ')
                            from unnest(_base_columns_for_upsert) as col
                        ) || '
                RETURNING *'
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
                ,' || (
                        select string_agg(quote_ident(col), ', ')
                        from unnest(_l10n_columns) as col
                    ) || '
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
