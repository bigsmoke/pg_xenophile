\pset tuples_only
\pset format unaligned

begin;

create extension pg_xenophile
    cascade;

select jsonb_pretty(xeno.pg_xenophile_meta_pgxn());

rollback;
