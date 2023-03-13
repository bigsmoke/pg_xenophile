-- Complain if script is sourced in psql, rather than via `CREATE EXTENSION`
\echo Use "CREATE EXTENSION pg_xenophile" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

-- Nicer, less abstract names for test table (columns).
-- Add extra columns to be sure to expose it when I forget to aggregate.
create or replace procedure test__l10n_table()
    set search_path from current
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

-- Add missing aggregate, to fix crash on more than one non-PK column in the base table.
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
