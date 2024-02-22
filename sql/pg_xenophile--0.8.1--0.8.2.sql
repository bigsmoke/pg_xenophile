-- Complain if script is sourced in `psql`, rather than via `CREATE EXTENSION`.
\echo Use "CREATE EXTENSION pg_xenophile" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

-- We don't allow records in the base table to belong to any extension other than `pg_xenophile` (or `NULL`),
-- so we can just blanket assign everything to `pg_xenophile`.
update country_subdivision_l10n set l10n_columns_belong_to_extension_name = 'pg_xenophile';

--------------------------------------------------------------------------------------------------------------
