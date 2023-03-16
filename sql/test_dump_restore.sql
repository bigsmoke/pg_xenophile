\o /dev/null
select  not :{?test_stage} as test_stage_missing
        ,not :{?extension_name} as extension_name_missing;
\o
\gset
\if :test_stage_missing
    \warn 'Missing `:test_stage` variable.'
    \quit
\endif
\if :extension_name_missing
    \warn 'Missing `:extension_name` variable.'
    \quit
\endif
\o /dev/null
select  :'test_stage' = 'pre-dump' as in_pre_dump_stage
        ,:'test_stage' = 'pre-restore' as in_pre_restore_stage;
\o
\gset

\set SHOW_CONTEXT 'errors'

\if :in_pre_restore_stage
    -- Let's generate some noise to offset the OIDs, to ensure that we're not relying on OIDs remaining the
    -- same between the moment of `pg_dump` and the moment of `pg_restore`.
    do $$
    declare
        _i int;
    begin
        for
            _i
        in select
            s.i
        from
            generate_series(1, 10) as s(i)
        loop
            execute format('CREATE TABLE test_dump_restore__oid_noise__tbl_%s (a int)', _i);
            execute format('CREATE TYPE test_dump_restore__oid_noise__rec_%s AS (a int, b int)', _i);
            execute format(
                'CREATE FUNCTION test_dump_restore__oid_noise__func_%s() RETURNS int RETURN 1'
                ,_i
            );
        end loop;
    end;
    $$;

    \quit
\endif

\if :in_pre_dump_stage
    create extension pg_xenophile with cascade;
\endif

call xeno.test_dump_restore__l10n_table(:'test_stage'::text);
