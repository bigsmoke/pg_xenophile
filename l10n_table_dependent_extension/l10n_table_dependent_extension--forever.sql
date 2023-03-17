-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION l10n_table_dependent_extension" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

create table subextension_tbl (
    natural_key text
        primary key
    ,base_tbl_col int
    ,base_row_belongs_to_subextension bool
        not null
        default false
);

select pg_catalog.pg_extension_config_dump('subextension_tbl', 'WHERE NOT base_row_belongs_to_subextension');

--------------------------------------------------------------------------------------------------------------

insert into l10n_table (
    base_table_name
    ,l10n_column_definitions
    ,base_lang_code
    ,target_lang_codes
    ,l10n_table_belongs_to_extension_name
)
values (
    'subextension_tbl'
    ,array[
        'localized_text text NOT NULL'
    ]
    ,'pt'
    ,array['es']
    ,'l10n_table_dependent_extension'
);

--------------------------------------------------------------------------------------------------------------

insert into subextension_tbl_l10n_pt
    (natural_key, base_row_belongs_to_subextension, l10n_columns_belong_to_extension_name, localized_text)
values
    ('👍', true, 'l10n_table_dependent_extension', 'bem')
;

--------------------------------------------------------------------------------------------------------------
