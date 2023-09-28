-- Complain if script is sourced in `psql`, rather than via `CREATE EXTENSION`.
\echo Use "CREATE EXTENSION pg_xenophile" to load this file. \quit

--------------------------------------------------------------------------------------------------------------


create domain country_subdivision_code
    as text
    check (value ~ '^[A-Z]{2}-[A-Z0-9]{1,3}$');

comment on domain country_subdivision_code is
$md$Using this domain instead of its underlying `text` type ensures that only [ISO 3166-2](https://www.iso.org/glossary-for-iso-3166.html) country subdivision codes are allowed with first 2 alpha2 characters, followed by a dash and 1 to 3 alphanumeric characters. For example, 'AB-A2B' would be allowed, as well as 'AB-1'.
$md$;

--------------------------------------------------------------------------------------------------------------

create domain country_subdivision_postal_abbreviation_code
    as text
    check (value ~ '^[A-Z0-9]{1,3}$');

comment on domain country_subdivision_postal_abbreviation_code is
$md$Using this domain instead of its underlying `text` type ensures that only country subdivision postal abbreviation codes with 1 to 3 alphanumeric characters are allowed. This follows the format of the second section of [ISO 3166-2](https://www.iso.org/glossary-for-iso-3166.html) subdivision codes.
$md$;

--------------------------------------------------------------------------------------------------------------

create table country_subdivision_type (
    subdivision_type_handle text
        primary key
);

comment on table country_subdivision_type is
$md$ The handle for the type of entity a subdivision is an identifier for the subdivision type, fe 'state', 'district' etc.
$md$;

--------------------------------------------------------------------------------------------------------------

create table country_subdivision (
    subdivision_code country_subdivision_code
        primary key
    ,country_code country_code_alpha2
        not null
        references country(country_code)
    ,subdivision_postal_abbreviation_code country_subdivision_postal_abbreviation_code
        not null
    ,subdivision_type_handle text
        not null
        references country_subdivision_type(subdivision_type_handle)
    ,unique(country_code,subdivision_postal_abbreviation_code)
);

comment on table country_subdivision is
$md$- *subdivision_code* [ISO 3166-2](https://www.iso.org/glossary-for-iso-3166.html) country subdivision code
- *country_code* [ISO 3166-1](https://www.iso.org/glossary-for-iso-3166.html) country code
- *subdivision_postal_abbreviation_code* the second part of country subdivision code
$md$;

--------------------------------------------------------------------------------------------------------------


insert into country_subdivision_type (
    subdivision_type_handle
)
values
    ('state')
    ,('territory')
    ,('district');

--------------------------------------------------------------------------------------------------------------

insert into l10n_table (
    base_table_name
    ,l10n_column_definitions
    ,base_lang_code, target_lang_codes
    ,l10n_table_belongs_to_extension_name
) values (
    'country_subdivision'::name
    ,array['name TEXT NOT NULL']
    ,'en'::lang_code_alpha2
    ,array[]::lang_code_alpha2[]
    ,'pg_xenophile'
);


-- This list is not (at all) complete!
-- Currently we only included the Australian and American subdivisions that are necessary for addresses,
-- as those were the only downstream requirements. If you need changes to the tree, make sure that these
-- changes are made in the `pg_xenophile` extension.

insert into country_subdivision_l10n_en (
    subdivision_code
    ,"name"
    ,country_code
    ,subdivision_postal_abbreviation_code
    ,subdivision_type_handle
)
values
    ('AU-NSW', 'New South Wales', 'AU', 'NSW', 'state')
    ,('AU-VIC', 'Victoria', 'AU', 'VIC', 'state')
    ,('AU-QLD', 'Queensland', 'AU', 'QLD', 'state')
    ,('AU-WA', 'Western Australia', 'AU', 'WA', 'state')
    ,('AU-SA', 'South Australia', 'AU', 'SA', 'state')
    ,('AU-TAS', 'Tasmania', 'AU', 'TAS', 'state')
    ,('AU-ACT', 'Australian Capital Territory', 'AU', 'ACT', 'territory')
    ,('AU-NT', 'Northern Territory', 'AU', 'NT', 'territory')
    ,('US-DC', 'District of Columbia', 'US', 'DC', 'district')
    ,('US-AL', 'Alabama', 'US', 'AL', 'state')
    ,('US-AK', 'Alaska', 'US', 'AK', 'state')
    ,('US-AZ', 'Arizona', 'US', 'AZ', 'state')
    ,('US-AR', 'Arkansas', 'US', 'AR', 'state')
    ,('US-CA', 'California', 'US', 'CA', 'state')
    ,('US-CO', 'Colorado', 'US', 'CO', 'state')
    ,('US-CT', 'Connecticut', 'US', 'CT', 'state')
    ,('US-DE', 'Delaware', 'US', 'DE', 'state')
    ,('US-FL', 'Florida', 'US', 'FL', 'state')
    ,('US-GA', 'Georgia', 'US', 'GA', 'state')
    ,('US-HI', 'Hawaii', 'US', 'HI', 'state')
    ,('US-ID', 'Idaho', 'US', 'ID', 'state')
    ,('US-IL', 'Illinois', 'US', 'IL', 'state')
    ,('US-IN', 'Indiana', 'US', 'IN', 'state')
    ,('US-IA', 'Iowa', 'US', 'IA', 'state')
    ,('US-KS', 'Kansas', 'US', 'KS', 'state')
    ,('US-KY', 'Kentucky', 'US', 'KY', 'state')
    ,('US-LA', 'Louisiana', 'US', 'LA', 'state')
    ,('US-ME', 'Maine', 'US', 'ME', 'state')
    ,('US-MD', 'Maryland', 'US', 'MD', 'state')
    ,('US-MA', 'Massachusetts', 'US', 'MA', 'state')
    ,('US-MI', 'Michigan', 'US', 'MI', 'state')
    ,('US-MN', 'Minnesota', 'US', 'MN', 'state')
    ,('US-MS', 'Mississippi', 'US', 'MS', 'state')
    ,('US-MO', 'Missouri', 'US', 'MO', 'state')
    ,('US-MT', 'Montana', 'US', 'MT', 'state')
    ,('US-NE', 'Nebraska', 'US', 'NE', 'state')
    ,('US-NV', 'Nevada', 'US', 'NV', 'state')
    ,('US-NH', 'New Hampshire', 'US', 'NH', 'state')
    ,('US-NJ', 'New Jersey', 'US', 'NJ', 'state')
    ,('US-NM', 'New Mexico', 'US', 'NM', 'state')
    ,('US-NY', 'New York', 'US', 'NY', 'state')
    ,('US-NC', 'North Carolina', 'US', 'NC', 'state')
    ,('US-ND', 'North Dakota', 'US', 'ND', 'state')
    ,('US-OH', 'Ohio', 'US', 'OH', 'state')
    ,('US-OK', 'Oklahoma', 'US', 'OK', 'state')
    ,('US-OR', 'Oregon', 'US', 'OR', 'state')
    ,('US-PA', 'Pennsylvania', 'US', 'PA', 'state')
    ,('US-RI', 'Rhode Island', 'US', 'RI', 'state')
    ,('US-SC', 'South Carolina', 'US', 'SC', 'state')
    ,('US-SD', 'South Dakota', 'US', 'SD', 'state')
    ,('US-TN', 'Tennessee', 'US', 'TN', 'state')
    ,('US-TX', 'Texas', 'US', 'TX', 'state')
    ,('US-UT', 'Utah', 'US', 'UT', 'state')
    ,('US-VT', 'Vermont', 'US', 'VT', 'state')
    ,('US-VA', 'Virginia', 'US', 'VA', 'state')
    ,('US-WA', 'Washington', 'US', 'WA', 'state')
    ,('US-WV', 'West Virginia', 'US', 'WV', 'state')
    ,('US-WI', 'Wisconsin', 'US', 'WI', 'state')
    ,('US-WY', 'Wyoming', 'US', 'WY', 'state')
;