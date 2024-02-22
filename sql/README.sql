\pset tuples_only
\pset format unaligned

begin;

create schema if not exists public;
create extension if not exists hstore;

create extension pg_xenophile
    cascade;

select xeno.pg_xenophile_readme();

rollback;
