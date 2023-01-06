---
pg_extension_name: pg_xenophile
pg_extension_version: 0.5.0
pg_readme_generated_at: 2023-01-06 12:56:06.655711+00
pg_readme_version: 0.3.7
---

# `pg_xenophile` PostgreSQL extension

The `pg_xenophile` PostgreSQL extension bundles a bunch of data, data
structures and routines that you often end up needing when working on an
international project:

- tables with the usual data that you need on countries, regions, languages
  and currencies;
- functions to easily store and access translated strings; and
- (trigger) functions to set up one-to-many translation tables with easy-to-use
  views on top.

It's perfectly valid to _just_ use `pg_xenophile` as a repository for
up-to-date lists of countries and languages and such.  But, the extension
becomes especially worthwhile if you want some comfort on top of the common
many-to-one translation-table pattern.

> All your ethnocentrism are belong to us.

## Extension-specific settings

| Extenion-hooked setting name     | `app.`-hooked setting name             | Default setting value           |
| -------------------------------- | -------------------------------------- | ------------------------------- |
| `pg_xenophile.base_lang_code`    | `app.settings.i18n.base_lang_code`     | `'en'::xeno.lang_code_alpha2`   |
| `pg_xenophile.user_lang_code`    | `app.settings.i18n.user_lang_code`     | `'en'::xeno.lang_code_alpha2`   |
| `pg_xenophile.target_lang_codes` | `app.settings.i18n.target_lang_codes`  | `'{}'::xeno.lang_code_alpha2[]` |

The reason that each `pg_xenophile` setting has an equivalent setting with an
`app.settings.i18n` prefix is because the powerful PostgREST can pass on such
settings from environment variables: `PGRST_APP_SETTINGS_*` maps to
`app.settings.*`.  The `app.settings.`-prefixed settings take precedence over
`pg_xenophile.`-prefixed settings.

Supporting _only_ the `app.settings.`-prefixed settings would not be a good
idea, because, in the circumstance that you would be running an extension
called “`app`”, these settings might disappear, as per the [relevant
documentation](https://www.postgresql.org/docs/15/runtime-config-custom.html):

> […]  Such variables are treated as placeholders and have no function until
> the module that defines them is loaded. When an extension module is loaded, it
> will add its variable definitions and convert any placeholder values according
> to those definitions. If there are any unrecognized placeholders that begin
> with its extension name, warnings are issued and those placeholders are
> removed.

In addition to the above, the `user_lang_code` setting, if set as neither
`app.settings.i18n.user_lang_code` and `pg_xenophile.user_lang_code`, falls
back to the first two letters of the `lc_messages` setting.

### Internal settings

| Setting name                                 | Default setting value           |
| -------------------------------------------- | ------------------------------- |
| `pg_xenophile.in_l10n_table_event_trigger`   | `false`                         |
| `pg_xenophile.in_l10n_table_row_trigger`     | `false`                         |

## Object reference

### Schema: `xeno`

`pg_xenophile` must be installed in the `xeno` schema.  Hence, it is not relocatable.

---

The `xeno` schema belongs to the `pg_xenophile` extension.

Postgres (as of Pg 15) doesn't allow one to specify a _default_ schema, and do
something like `schema = 'xeno'` combined with `relocatable = true` in the
`.control` file.  Therefore I decided to bluntly force the `xeno` schema name
upon you, even though you might have very well (and justifyingly so) preferred
something like `i18n`.

### Tables

There are 8 tables that directly belong to the `pg_xenophile` extension.

#### Table: `eu_country`

The `eu_country` table has 3 attributes:

1. `eu_country.country_code` `country_code_alpha2`

   - `NOT NULL`
   - `PRIMARY KEY (country_code)`
   - `FOREIGN KEY (country_code) REFERENCES country(country_code)`

2. `eu_country.eu_membership_checked_on` `date`

3. `eu_country.eu_country_belongs_to_pg_xenophile` `boolean`

   - `NOT NULL`
   - `DEFAULT false`

#### Table: `currency`

The `currency` table contains the currencies known to `pg_xenophile`.

The `currency` table has 5 attributes:

1. `currency.currency_code` `currency_code`

   `currency_code` is a 3-letter ISO 4217 currency code.

   - `NOT NULL`
   - `PRIMARY KEY (currency_code)`

2. `currency.currency_code_num` `text`

   `currency_code` is the numeric 3-digit ISO 4217 currency code.

   - `NOT NULL`
   - `CHECK (currency_code_num ~ '^[0-9]{3}$'::text)`
   - `UNIQUE (currency_code_num)`

3. `currency.currency_symbol` `text`

   - `NOT NULL`
   - `CHECK (length(currency_symbol) = 1)`

4. `currency.decimal_digits` `integer`

   - `NOT NULL`
   - `DEFAULT 2`

5. `currency.currency_belongs_to_pg_xenophile` `boolean`

   Does this currency belong to the `pg_xenophile` extension or not.

   If `NOT currency_belongs_to_pg_xenophile`, it is considered a custom currency
   inserted by the extension user rather than the extension developer.  Instead
   (or in addition) of adding such custom rows, please feel free to submit patches
   with all the currencies that you wish for `pg_xenophile` to embrace.

   - `NOT NULL`
   - `DEFAULT false`

#### Table: `country`

The ISO 3166-1 alpha-2, alpha3 and numeric country codes, as well as some auxillary information.

The `country` table has 6 attributes:

1. `country.country_code` `country_code_alpha2`

   - `NOT NULL`
   - `PRIMARY KEY (country_code)`

2. `country.country_code_alpha3` `text`

   - `CHECK (country_code_alpha3 ~ '^[A-Z]{3}$'::text)`
   - `UNIQUE (country_code_alpha3)`

3. `country.country_code_num` `text`

   - `NOT NULL`
   - `CHECK (country_code_num ~ '^[0-9]{3}$'::text)`

4. `country.calling_code` `integer`

   - `NOT NULL`

5. `country.currency_code` `text`

   - `NOT NULL`
   - `DEFAULT 'EUR'::text`
   - `FOREIGN KEY (currency_code) REFERENCES currency(currency_code) ON UPDATE CASCADE ON DELETE RESTRICT`

6. `country.country_belongs_to_pg_xenophile` `boolean`

   - `NOT NULL`
   - `DEFAULT false`

#### Table: `country_postal_code_pattern`

The `country_postal_code_pattern` table has 8 attributes:

1. `country_postal_code_pattern.country_code` `country_code_alpha2`

   - `NOT NULL`
   - `PRIMARY KEY (country_code)`
   - `FOREIGN KEY (country_code) REFERENCES country(country_code)`

2. `country_postal_code_pattern.valid_postal_code_regexp` `text`

   - `NOT NULL`

3. `country_postal_code_pattern.clean_postal_code_regexp` `text`

4. `country_postal_code_pattern.clean_postal_code_replace` `text`

5. `country_postal_code_pattern.postal_code_example` `text`

   - `NOT NULL`

6. `country_postal_code_pattern.postal_code_pattern_checked_on` `date`

7. `country_postal_code_pattern.postal_code_pattern_information_source` `text`

8. `country_postal_code_pattern.postal_code_pattern_belongs_to_pg_xenophile` `boolean`

   - `NOT NULL`
   - `DEFAULT false`

#### Table: `l10n_table`

The `l10n_table` table is meant to keep track and manage all the
`_l10n`-suffixed tables.  By inserting a row in this table, with just the
details of the base table, a many-to-one l10n table called
`<base_table_name>_l10n` will be created by the `maintain_l10n_objects`
trigger.  This trigger will also take care of creating the
`<base_table_name>_l10n_<base_lang_code>` view as well as one such view for
all the `target_lang_codes`.  These views combine the columns of the base
table with the columns of the l10n table, filtered by the language code
specific to that particular view.

One of the reasons to manage this through a table rather than through a stored
procedure is that a list of such enhance l10n tables needs to be kept by
`pg_xenophile` anyway: in the likely case that updates necessitate the
upgrading of (the views and/or triggers around) these tables, the extension
update script will know where to find everything.

It may not immediately be obvious why, besides the `base_table_regclass` and
the `l10n_table_regclass` columns, `schema_name`, `base_table_name` and
`l10n_table_name` also exist.  After all, PostgreSQL has some very comfortable
magic surrounding `regclass` and related [object identifier
types](https://www.postgresql.org/docs/current/datatype-oid.html).  The reason
is that, even though `pg_dump` has the ability to dump OIDs, tables belonging
to extensions are not dumped at all, except for any part exempted from this
using the `pg_catalog.pg_extension_config_dump()` function.  For `l10n_table`,
only the columns for which `l10n_table_belongs_to_pg_xenophile = false` are
included in the dump.

The `l10n_table` table has 11 attributes:

1. `l10n_table.schema_name` `name`

   - `NOT NULL`
   - `DEFAULT CURRENT_SCHEMA`

2. `l10n_table.base_table_name` `name`

   - `NOT NULL`

3. `l10n_table.base_table_regclass` `regclass`

   - `NOT NULL`
   - `PRIMARY KEY (base_table_regclass)`

4. `l10n_table.base_column_definitions` `text[]`

   - `NOT NULL`

5. `l10n_table.l10n_table_name` `name`

   - `NOT NULL`

6. `l10n_table.l10n_table_regclass` `regclass`

   - `NOT NULL`
   - `UNIQUE (l10n_table_regclass)`

7. `l10n_table.l10n_column_definitions` `text[]`

   - `NOT NULL`

8. `l10n_table.l10n_table_constraint_definitions` `text[]`

   - `NOT NULL`
   - `DEFAULT ARRAY[]::text[]`

9. `l10n_table.base_lang_code` `lang_code_alpha2`

   - `NOT NULL`
   - `DEFAULT pg_xenophile_base_lang_code()`

10. `l10n_table.target_lang_codes` `lang_code_alpha2[]`

   - `NOT NULL`
   - `DEFAULT pg_xenophile_target_lang_codes()`

11. `l10n_table.l10n_table_belongs_to_pg_xenophile` `boolean`

   If this is `true`, then the created localization (l10n) _table_ will be managed
   (and thus recreated after a restore) by the `pg_xenophile` extension.  That is
   _not_ the same as saying that the l10n table's rows will belong to
   `pg_xenophile`.  To determine the latter, a `l10n_columns_belong_to_pg_xenophile`
   column will be added to the l10n table if `create_l10n_table()` was called with
   the `will_belong_to_pg_xenophile$ => true` argument.

   Only developers of this extension need to worry about these booleans.  For
   users, the default of `false` assures that they will lose none of their precious
   data.

   - `NOT NULL`
   - `DEFAULT false`

#### Table: `lang`

The `lang` table has 2 attributes:

1. `lang.lang_code` `lang_code_alpha2`

   ISO 639-1 two-letter (lowercase) language code.

   - `NOT NULL`
   - `PRIMARY KEY (lang_code)`

2. `lang.lang_belongs_to_pg_xenophile` `boolean`

   - `NOT NULL`
   - `DEFAULT false`

#### Table: `lang_l10n`

This table is managed by the `pg_xenophile` extension, which has delegated its creation to the `maintain_l10n_objects` trigger on the `l10n_table` table.  To alter this table, just `ALTER` it as you normally would.  The `l10n_table__track_alter_table_events` event trigger will detect such changes, as well as changes to the base table (`lang`) referenced by the foreign key (that doubles as primary key) on `lang_l10n`.  When any `ALTER TABLE lang_l10n` or `ALTER TABLE lang` events are detected, `l10n_table`  will be updated—the `base_column_definitions`, `l10n_column_definitions` and `l10n_table_constraint_definitions` columns—with the latest information from the `pg_catalog`.

These changes to `l10n_table` in turn trigger the `maintain_l10n_objects` trigger, which ensures that the language-specific convenience views that (left) join `lang` to `lang_l10n` are kept up-to-date with the columns in these tables.

To drop this table, either just `DROP TABLE` it (and the `l10n_table__track_drop_table_events` will take care of the book-keeping or delete its bookkeeping row from `l10n_table`.

The `lang_l10n` table has 4 attributes:

1. `lang_l10n.lang_code` `lang_code_alpha2`

   - `NOT NULL`
   - `FOREIGN KEY (lang_code) REFERENCES lang(lang_code) ON UPDATE CASCADE ON DELETE CASCADE`

2. `lang_l10n.l10n_lang_code` `lang_code_alpha2`

   - `NOT NULL`
   - `FOREIGN KEY (l10n_lang_code) REFERENCES lang(lang_code) ON UPDATE RESTRICT ON DELETE RESTRICT`

3. `lang_l10n.l10n_columns_belong_to_pg_xenophile` `boolean`

   - `NOT NULL`
   - `DEFAULT false`

4. `lang_l10n.name` `text`

   - `NOT NULL`

#### Table: `country_l10n`

This table is managed by the `pg_xenophile` extension, which has delegated its creation to the `maintain_l10n_objects` trigger on the `l10n_table` table.  To alter this table, just `ALTER` it as you normally would.  The `l10n_table__track_alter_table_events` event trigger will detect such changes, as well as changes to the base table (`country`) referenced by the foreign key (that doubles as primary key) on `country_l10n`.  When any `ALTER TABLE country_l10n` or `ALTER TABLE country` events are detected, `l10n_table`  will be updated—the `base_column_definitions`, `l10n_column_definitions` and `l10n_table_constraint_definitions` columns—with the latest information from the `pg_catalog`.

These changes to `l10n_table` in turn trigger the `maintain_l10n_objects` trigger, which ensures that the language-specific convenience views that (left) join `country` to `country_l10n` are kept up-to-date with the columns in these tables.

To drop this table, either just `DROP TABLE` it (and the `l10n_table__track_drop_table_events` will take care of the book-keeping or delete its bookkeeping row from `l10n_table`.

The `country_l10n` table has 4 attributes:

1. `country_l10n.country_code` `country_code_alpha2`

   - `NOT NULL`
   - `FOREIGN KEY (country_code) REFERENCES country(country_code) ON UPDATE CASCADE ON DELETE CASCADE`

2. `country_l10n.l10n_lang_code` `lang_code_alpha2`

   - `NOT NULL`
   - `FOREIGN KEY (l10n_lang_code) REFERENCES lang(lang_code) ON UPDATE RESTRICT ON DELETE RESTRICT`

3. `country_l10n.l10n_columns_belong_to_pg_xenophile` `boolean`

   - `NOT NULL`
   - `DEFAULT false`

4. `country_l10n.name` `text`

   - `NOT NULL`

### Views

#### View: `lang_l10n_en`

```
 SELECT lang.lang_code, lang.lang_belongs_to_pg_xenophile,
    lang_l10n.l10n_lang_code, lang_l10n.l10n_columns_belong_to_pg_xenophile,
    lang_l10n.name
   FROM lang
     LEFT JOIN lang_l10n ON lang.lang_code::text = lang_l10n.lang_code::text AND lang_l10n.l10n_lang_code::text = 'en'::text;
```

#### View: `country_l10n_en`

```
 SELECT country.country_code, country.country_code_alpha3,
    country.country_code_num, country.calling_code, country.currency_code,
    country.country_belongs_to_pg_xenophile, country_l10n.l10n_lang_code,
    country_l10n.l10n_columns_belong_to_pg_xenophile, country_l10n.name
   FROM country
     LEFT JOIN country_l10n ON country.country_code::text = country_l10n.country_code::text AND country_l10n.l10n_lang_code::text = 'en'::text;
```

### Routines

#### Procedure: `create_l10n_view (name, name, name, lang_code_alpha2, boolean)`

Procedure arguments:

| Arg. # | Arg. mode  | Argument name                                                     | Argument type                                                        | Default expression  |
| ------ | ---------- | ----------------------------------------------------------------- | -------------------------------------------------------------------- | ------------------- |
|   `$1` |       `IN` | `table_schema$`                                                   | `name`                                                               |  |
|   `$2` |       `IN` | `base_table$`                                                     | `name`                                                               |  |
|   `$3` |       `IN` | `l10n_table$`                                                     | `name`                                                               |  |
|   `$4` |       `IN` | `lang_code$`                                                      | `lang_code_alpha2`                                                   |  |
|   `$5` |       `IN` | `temp$`                                                           | `boolean`                                                            | `false` |

Procedure-local settings:

  *  `SET search_path TO xeno, public, pg_temp`

#### Function: `fkey_guard (regclass, name, anyelement)`

Function arguments:

| Arg. # | Arg. mode  | Argument name                                                     | Argument type                                                        | Default expression  |
| ------ | ---------- | ----------------------------------------------------------------- | -------------------------------------------------------------------- | ------------------- |
|   `$1` |       `IN` | `foreign_table$`                                                  | `regclass`                                                           |  |
|   `$2` |       `IN` | `fkey_column$`                                                    | `name`                                                               |  |
|   `$3` |       `IN` | `fkey_value$`                                                     | `anyelement`                                                         |  |

Function return type: `anyelement`

Function attributes: `STABLE`, `RETURNS NULL ON NULL INPUT`, `PARALLEL SAFE`

#### Function: `l10n_table__maintain_l10n_objects ()`

The `l10n_table__maintain_l10n_objects()` trigger function is meant to actuate
changes to the `l10_table` to the actual l10n tables and views tracked by that
meta table.

Function return type: `trigger`

Function-local settings:

  *  `SET search_path TO xeno, public, pg_temp`
  *  `SET pg_xenophile.in_l10n_table_row_trigger TO true`

#### Function: `l10n_table__track_alter_table_events ()`

Function return type: `event_trigger`

Function attributes: `SECURITY DEFINER`

Function-local settings:

  *  `SET search_path TO xeno, public, pg_temp`
  *  `SET pg_xenophile.in_l10n_table_event_trigger TO true`

#### Function: `l10n_table__track_drop_table_events ()`

Function return type: `event_trigger`

Function attributes: `SECURITY DEFINER`

Function-local settings:

  *  `SET search_path TO xeno, public, pg_temp`
  *  `SET pg_xenophile.in_l10n_table_event_trigger TO true`

#### Function: `l10n_table_with_fresh_ddl (l10n_table)`

Function arguments:

| Arg. # | Arg. mode  | Argument name                                                     | Argument type                                                        | Default expression  |
| ------ | ---------- | ----------------------------------------------------------------- | -------------------------------------------------------------------- | ------------------- |
|   `$1` |    `INOUT` |                                                                   | `l10n_table`                                                         |  |

Function return type: `l10n_table`

Function attributes: `STABLE`

Function-local settings:

  *  `SET search_path TO xeno, public, pg_temp`

#### Function: `pg_xenophile_base_lang_code ()`

Function return type: `lang_code_alpha2`

Function attributes: `STABLE`, `LEAKPROOF`

Function-local settings:

  *  `SET pg_readme.include_this_routine_definition TO true`
  *  `SET search_path TO xeno, public, pg_temp`

```
CREATE OR REPLACE FUNCTION xeno.pg_xenophile_base_lang_code()
 RETURNS lang_code_alpha2
 LANGUAGE sql
 STABLE LEAKPROOF
 SET "pg_readme.include_this_routine_definition" TO 'true'
 SET search_path TO 'xeno', 'public', 'pg_temp'
RETURN (COALESCE(current_setting('app_settings.i18n.base_lang_code'::text, true), current_setting('pg_xenophile.base_lang_code'::text, true), 'en'::text))::lang_code_alpha2
```

#### Function: `pg_xenophile_meta_pgxn ()`

Function return type: `jsonb`

Function attributes: `STABLE`

#### Function: `pg_xenophile_readme ()`

Generates a README in Markdown format using the amazing power of the
`pg_readme` extension.  Temporarily installs `pg_readme` if it is not already
installed in the current database.

Function return type: `text`

Function-local settings:

  *  `SET search_path TO xeno, public, pg_temp`
  *  `SET pg_readme.include_view_definitions TO true`
  *  `SET pg_readme.include_routine_definitions_like TO {test__%}`

#### Function: `pg_xenophile_target_lang_codes ()`

Function return type: `lang_code_alpha2[]`

Function attributes: `STABLE`, `LEAKPROOF`

Function-local settings:

  *  `SET pg_readme.include_this_routine_definition TO true`
  *  `SET search_path TO xeno, public, pg_temp`

```
CREATE OR REPLACE FUNCTION xeno.pg_xenophile_target_lang_codes()
 RETURNS lang_code_alpha2[]
 LANGUAGE sql
 STABLE LEAKPROOF
 SET "pg_readme.include_this_routine_definition" TO 'true'
 SET search_path TO 'xeno', 'public', 'pg_temp'
RETURN (COALESCE(current_setting('app.settings.i18n.target_lang_codes'::text, true), current_setting('pg_xenophile.target_lang_codes'::text, true), '{}'::text))::lang_code_alpha2[]
```

#### Function: `pg_xenophile_user_lang_code ()`

Function return type: `lang_code_alpha2`

Function attributes: `STABLE`, `LEAKPROOF`

Function-local settings:

  *  `SET pg_readme.include_this_routine_definition TO true`
  *  `SET search_path TO xeno, public, pg_temp`

```
CREATE OR REPLACE FUNCTION xeno.pg_xenophile_user_lang_code()
 RETURNS lang_code_alpha2
 LANGUAGE sql
 STABLE LEAKPROOF
 SET "pg_readme.include_this_routine_definition" TO 'true'
 SET search_path TO 'xeno', 'public', 'pg_temp'
RETURN (COALESCE(current_setting('app_settings.i18n.user_lang_code'::text, true), current_setting('pg_xenophile.user_lang_code'::text, true), regexp_replace(current_setting('lc_messages'::text), '^([a-z]{2}).*$'::text, ''::text), 'en'::text))::lang_code_alpha2
```

#### Procedure: `test__l10n_table ()`

Procedure-local settings:

  *  `SET search_path TO xeno, public, pg_temp`
  *  `SET pg_readme.include_this_routine_definition TO true`

```
CREATE OR REPLACE PROCEDURE xeno.test__l10n_table()
 LANGUAGE plpgsql
 SET search_path TO 'xeno', 'public', 'pg_temp'
 SET "pg_readme.include_this_routine_definition" TO 'true'
AS $procedure$
declare
    _row record;
    _nl_expected_1 record;
    _nl_expected_2 record;
    _en_expected_1 record;
    _l10n_table l10n_table;
begin
    create table test_tbl_a (
        id bigint
            primary key
            generated always as identity
        ,universal_blergh text
    );

    insert into l10n_table (base_table_name, l10n_column_definitions, base_lang_code, target_lang_codes)
    values (
        'test_tbl_a'
        ,array['name TEXT NOT NULL', 'description TEXT NOT NULL']
        ,'nl'::lang_code_alpha2  -- Apologies for the Dutch East India Company mentality.
        ,array['en', 'fr']::lang_code_alpha2[]
    );

    assert array['test_tbl_a_l10n_en', 'test_tbl_a_l10n_fr', 'test_tbl_a_l10n_nl']::name[] = (
        select      array_agg(views.table_name order by views.table_name)::name[]
        from        information_schema.views
        where       views.table_schema = current_schema
                    and views.table_name like 'test\_tbl\_a\_l10n\___'
    );

    _nl_expected_1 := row(
        1, 'AX-UNI', 'nl', 'Bijl Universiteit', 'De trainingsleider in bijlonderhoud en gebruik'
    )::test_tbl_a_l10n_nl;

    insert into test_tbl_a_l10n_nl (universal_blergh, "name", "description")
        values (_nl_expected_1.universal_blergh, _nl_expected_1."name", _nl_expected_1."description")
        returning *
        into _row;

    assert _row = _nl_expected_1;

    assert _nl_expected_1 = (select row(tbl.*)::test_tbl_a_l10n_nl from test_tbl_a_l10n_nl as tbl);

    _en_expected_1 := row(
        1, 'AX-UNI', 'en', 'Axe University', 'The leader in axe maintenance and usage training'
    )::test_tbl_a_l10n_en;

    update test_tbl_a_l10n_en
        set "name" = _en_expected_1."name"
            ,"description" = _en_expected_1."description"
        where
            id = _nl_expected_1.id
        returning
            *
        into
            _row;

    assert _row = _en_expected_1,
        format('%s ≠ %s', _row, _en_expected_1);

    assert _en_expected_1 = (select row(tbl.*)::test_tbl_a_l10n_en from test_tbl_a_l10n_en as tbl);

    _nl_expected_2 := row(
        2, 'PO-UNI', 'nl', 'Poep-Universiteit', 'De Beste Plek om Te Leren Legen'
    )::test_tbl_a_l10n_nl;

    insert into test_tbl_a_l10n_nl (universal_blergh, "name", "description")
        values (_nl_expected_2.universal_blergh, _nl_expected_2."name", _nl_expected_2."description")
        returning *
        into _row;
    assert _row = _nl_expected_2;

    delete from test_tbl_a_l10n_fr where id = 1;
    assert found;

    <<trigger_alter_table_event>>
    begin
        alter table test_tbl_a_l10n
            add description2 text;

        update test_tbl_a_l10n
            set description2 = 'Something to satisfy NOT NULL';  -- Because we want to make it NOT NULL.

        alter table test_tbl_a_l10n
            alter column description2 set not null;

        select * into _l10n_table from l10n_table where base_table_name = 'test_tbl_a';

        assert _l10n_table.l10n_column_definitions[3] = 'description2 text NOT NULL',
            'The `l10n_table__track_alter_table_events` event trigger should have updated the list of l10n'
            ' columns.';

        assert exists(
                select
                from    pg_attribute
                where   attrelid = 'test_tbl_a_l10n_fr'::regclass
                        and attname = 'description2'
            ), 'The `description2` column should have been added to the view.';

        alter table test_tbl_a_l10n
            drop column description2
            cascade;

        select * into _l10n_table from l10n_table where base_table_name = 'test_tbl_a';

        assert array_length(_l10n_table.l10n_column_definitions, 1) = 2,
            'The dropped column should have been removed from the `l10n_table` meta table.';

        assert not exists(
                select
                from    pg_attribute
                where   attrelid = 'test_tbl_a_l10n_nl'::regclass
                        and attname = 'description2'
            ), 'The `description2` column should have disappeared from the views.';

        alter table test_tbl_a
            add non_l10n_col int
                not null
                default 6;

        select * into _l10n_table from l10n_table where base_table_name = 'test_tbl_a';

        assert _l10n_table.base_column_definitions[3] = 'non_l10n_col integer NOT NULL DEFAULT 6',
            'The `l10n_table__track_alter_table_events` event trigger should have updated the list of base'
            ' columns.';

        assert (select non_l10n_col from test_tbl_a_l10n_nl where id = 2) = 6;

        alter table test_tbl_a
            drop column non_l10n_col
            cascade;

        assert not exists(
                select
                from    pg_attribute
                where   attrelid = 'test_tbl_a_l10n_nl'::regclass
                        and attname = 'non_l10n_col'
            ), 'The `non_l10n_col` column should have disappeared from the views.';

        <<drop_base_table>>
        begin
            drop table test_tbl_a cascade;

            assert not exists (select from l10n_table where base_table_name = 'test_tbl_a');

            raise transaction_rollback;  -- I could have used any error code, but this one seemed to fit best.
        exception
            when transaction_rollback then
        end drop_base_table;
    end trigger_alter_table_event;

    delete from l10n_table where base_table_regclass = 'test_tbl_a'::regclass;

    raise transaction_rollback;  -- I could have used any error code, but this one seemed to fit best.
exception
    when transaction_rollback then
end;
$procedure$
```

#### Function: `updatable_l10_view ()`

Function return type: `trigger`

Function-local settings:

  *  `SET search_path TO xeno, public, pg_temp`

### Types

The following extra types have been defined _besides_ the implicit composite types of the [tables](#tables) and [views](#views) in this extension.

#### Type: `currency_code`

TODO: automatic type synopsis in `pg_readme_object_reference()`.

#### Type: `country_code_alpha2`

TODO: automatic type synopsis in `pg_readme_object_reference()`.

#### Type: `lang_code_alpha2`

TODO: automatic type synopsis in `pg_readme_object_reference()`.

## Colophon

This `README.md` for the `pg_xenophile` `extension` was automatically generated using the [`pg_readme`](https://github.com/bigsmoke/pg_readme) PostgreSQL extension.
