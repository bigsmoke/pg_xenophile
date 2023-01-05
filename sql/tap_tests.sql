begin;

create extension pg_xenophile
    with cascade;

call xeno.test__l10n_table();

rollback;
