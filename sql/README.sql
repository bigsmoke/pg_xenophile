\pset tuples_only
\pset format unaligned

begin;

create extension pg_xenophile
    cascade;

select xeno.pg_xenophile_readme();

rollback;
