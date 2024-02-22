\pset tuples_only
\pset format unaligned

begin;

create schema if not exists ext;
set search_path to ext;
create extension if not exists hstore;

create extension pg_xenophile
    cascade;

select jsonb_pretty(xeno.pg_xenophile_meta_pgxn());

rollback;
