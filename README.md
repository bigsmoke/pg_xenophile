---
pg_extension_name: pg_xenophile
pg_extension_version: 0.7.4
pg_readme_generated_at: 2023-05-29 12:18:20.020209+01
pg_readme_version: 0.6.4
---

# `pg_xenophile` PostgreSQL extension

[![PGXN version](https://badge.fury.io/pg/pg_xenophile.svg)](https://badge.fury.io/pg/pg_xenophile)

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

## Using `pg_xenophile`

To use the list of countries (from the [`country` table](#table-country)) or
languages (from the [`lang` table](#table-lang), just use them.  And don't be
afraid of using the natural keys in your foreign keys!  If you've been told to
fear them, you will soon be attached to the convenience of not needing to join
to know what a foreign key value means.

If you want a translatable table, you have to register the base table with the
[`l10n_table` meta table](#table-l10n_table).  See the [`l10n_table`
documentation](#table-l10n_table) in the reference for details.  From the
`l10n_table` documentation, you should also be able to learn how to work with
the `lang_l10n`, `lang_l10n_en`, `country_l10n` and `country_l10n_en` tables
and views that are manintained via the triggers on this meta table.

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
| `pg_xenophile.pg_restore_seems_active`       | `false`                         |

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

#### Table: `l10n_table`

The `l10n_table` table is meant to keep track and manage all the `_l10n`-suffixed tables.

By inserting a row in this table, with just the
details of the base table, a many-to-one l10n table called
`<base_table_name>_l10n` will be created by the `maintain_l10n_objects`
trigger.  This trigger will also take care of creating the
`<base_table_name>_l10n_<base_lang_code>` view as well as one such view for
all the `target_lang_codes`.  These views combine the columns of the base
table with the columns of the l10n table, filtered by the language code
specific to that particular view.

One of the reasons to manage this through a table rather than through a stored
procedure is that a list of such enhanced l10n tables needs to be kept by
`pg_xenophile` anyway: in the likely case that updates necessitate the
upgrading of (the views and/or triggers around) these tables, the extension
update script will know where to find everything.

It may not immediately be obvious why, besides the `base_table_regclass` and
the `l10n_table_regclass` columns, `schema_name`, `base_table_name` and
`l10n_table_name` also exist.  After all, PostgreSQL has some very comfortable
magic surrounding `regclass` and related [object identifier
types](https://www.postgresql.org/docs/current/datatype-oid.html).  Two reasons:

1.  Even though `pg_dump` has the ability to dump OIDs, tables belonging
    to extensions are not dumped at all, except for any part exempted from this
    using the `pg_catalog.pg_extension_config_dump()` function.  For
    `l10n_table`, only the columns for which
    `l10n_table_belongs_to_extension_name IS NULL` are included in the dump.
2.  OIDs of tables and other catalog objects are not guaranteed to remain the
    same between `pg_dump` and `pg_restore`.

The `l10n_table` table has 12 attributes:

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

11. `l10n_table.l10n_table_belongs_to_extension_name` `name`

   This column must be `NOT NULL` if the l10n table is created through extension setup scripts and its row in the meta table must thus be omitted from `pg_dump`.

   If `l10n_table_belongs_to_extension_name IS NOT NULL`, then the created
   localization (l10n) _table_ will be managed (and thus recreated during a
   restore) by the named extension's setup/upgrade script.  That is _not_ the same
   as saying that the l10n table's _rows_ will belong to `pg_xenophile`.  To
   determine the latter, a `l10n_columns_belong_to_extension_name` column will be
   added to the l10n table if the `l10n_table__maintain_l10n_objects()` trigger
   function finds `l10n_table_belongs_to_extension_name IS NOT NULL` on insert.

   Only developers of this or dependent extensions need to worry about these
   booleans.  For users, the default of `false` assures that they will lose none
   of their precious data.

12. `l10n_table.l10n_table_belongs_to_extension_version` `text`

#### Table: `lang`

The `lang` table has 2 attributes:

1. `lang.lang_code` `lang_code_alpha2`

   ISO 639-1 two-letter (lowercase) language code.

   - `NOT NULL`
   - `PRIMARY KEY (lang_code)`

2. `lang.lang_belongs_to_pg_xenophile` `boolean`

   `pg_dump` will ignore rows for which this is `true`.

   Make sure that this column is `false` when you add your own language.  When
   your language is an official language according to the ISO standard, please
   make sure that it will be included upstream in `pg_xenophile`, so that all
   users of the extension can profit from up-to-date information.

   Please note, that you will run into problems with dump/restore when you add
   records to this table from within your own dependent extension set up scripts.

   - `NOT NULL`
   - `DEFAULT false`

#### Table: `lang_l10n`

This table is managed by the `pg_xenophile` extension, which has delegated its creation to the `maintain_l10n_objects` trigger on the `l10n_table` table.  To alter this table, just `ALTER` it as you normally would.  The `l10n_table__track_alter_table_events` event trigger will detect such changes, as well as changes to the base table (`lang`) referenced by the foreign key (that doubles as primary key) on `lang_l10n`.  When any `ALTER TABLE lang_l10n` or `ALTER TABLE lang` events are detected, `l10n_table`  will be updated—the `base_column_definitions`, `l10n_column_definitions` and `l10n_table_constraint_definitions` columns—with the latest information from the `pg_catalog`.

These changes to `l10n_table` in turn trigger the `maintain_l10n_objects` trigger, which ensures that the language-specific convenience views that (left) join `lang` to `lang_l10n` are kept up-to-date with the columns in these tables.

To drop this table, either just `DROP TABLE` it (and the `l10n_table__track_drop_table_events` will take care of the book-keeping or delete its bookkeeping row from `l10n_table`.

The `lang_l10n` table has 5 attributes:

1. `lang_l10n.lang_code` `lang_code_alpha2`

   - `NOT NULL`
   - `FOREIGN KEY (lang_code) REFERENCES lang(lang_code) ON UPDATE CASCADE ON DELETE CASCADE`

2. `lang_l10n.l10n_lang_code` `lang_code_alpha2`

   - `NOT NULL`
   - `FOREIGN KEY (l10n_lang_code) REFERENCES lang(lang_code) ON UPDATE RESTRICT ON DELETE RESTRICT`

3. `lang_l10n.l10n_columns_belong_to_extension_name` `name`

4. `lang_l10n.l10n_columns_belong_to_extension_version` `text`

5. `lang_l10n.name` `text`

   - `NOT NULL`

#### Table: `country_l10n`

This table is managed by the `pg_xenophile` extension, which has delegated its creation to the `maintain_l10n_objects` trigger on the `l10n_table` table.  To alter this table, just `ALTER` it as you normally would.  The `l10n_table__track_alter_table_events` event trigger will detect such changes, as well as changes to the base table (`country`) referenced by the foreign key (that doubles as primary key) on `country_l10n`.  When any `ALTER TABLE country_l10n` or `ALTER TABLE country` events are detected, `l10n_table`  will be updated—the `base_column_definitions`, `l10n_column_definitions` and `l10n_table_constraint_definitions` columns—with the latest information from the `pg_catalog`.

These changes to `l10n_table` in turn trigger the `maintain_l10n_objects` trigger, which ensures that the language-specific convenience views that (left) join `country` to `country_l10n` are kept up-to-date with the columns in these tables.

To drop this table, either just `DROP TABLE` it (and the `l10n_table__track_drop_table_events` will take care of the book-keeping or delete its bookkeeping row from `l10n_table`.

The `country_l10n` table has 5 attributes:

1. `country_l10n.country_code` `country_code_alpha2`

   - `NOT NULL`
   - `FOREIGN KEY (country_code) REFERENCES country(country_code) ON UPDATE CASCADE ON DELETE CASCADE`

2. `country_l10n.l10n_lang_code` `lang_code_alpha2`

   - `NOT NULL`
   - `FOREIGN KEY (l10n_lang_code) REFERENCES lang(lang_code) ON UPDATE RESTRICT ON DELETE RESTRICT`

3. `country_l10n.l10n_columns_belong_to_extension_name` `name`

4. `country_l10n.l10n_columns_belong_to_extension_version` `text`

5. `country_l10n.name` `text`

   - `NOT NULL`

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

   `pg_dump` will ignore rows for which this is `true`.

   Make sure that this column is `false` when you add your own country.  When your
   country is an official country according to the ISO standard, please make sure
   that it will be included upstream in `pg_xenophile`, so that all users of the
   extension can profit from up-to-date information.

   Please note, that you will run into problems with dump/restore when you add
   records to this table from within your own dependent extension set up scripts.

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

   Whether or not this pattern was shipped with the `pg_xenophile` extension.

   Make sure that, for your custom additions to this table, this column is
   `false`.  Even better, though: contribute new or updated postal code patterns
   upstream, to `pg_xenophile`, so that everybody may profit from your knowledge.

   Please note, that you will run into problems with dump/restore when you add
   records to this table from within your own dependent extension set up scripts.

   - `NOT NULL`
   - `DEFAULT false`

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

### Views

#### View: `lang_l10n_en`

```sql
 SELECT lang.lang_code, lang.lang_belongs_to_pg_xenophile,
    lang_l10n.l10n_lang_code, lang_l10n.l10n_columns_belong_to_extension_name,
    lang_l10n.l10n_columns_belong_to_extension_version, lang_l10n.name
   FROM lang
     LEFT JOIN lang_l10n ON lang.lang_code::text = lang_l10n.lang_code::text AND lang_l10n.l10n_lang_code::text = 'en'::text;
```

#### View: `country_l10n_en`

```sql
 SELECT country.country_code, country.country_code_alpha3,
    country.country_code_num, country.calling_code, country.currency_code,
    country.country_belongs_to_pg_xenophile, country_l10n.l10n_lang_code,
    country_l10n.l10n_columns_belong_to_extension_name,
    country_l10n.l10n_columns_belong_to_extension_version, country_l10n.name
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

#### Function: `l10n_table__maintain_l10n_objects()`

The `l10n_table__maintain_l10n_objects()` trigger function is meant to actuate changes to the `l10_table` to the actual l10n tables and views tracked by that meta table.

Function return type: `trigger`

Function-local settings:

  *  `SET search_path TO xeno, public, pg_temp`
  *  `SET pg_xenophile.in_l10n_table_row_trigger TO true`

#### Function: `l10n_table__track_alter_table_events()`

Function return type: `event_trigger`

Function attributes: `SECURITY DEFINER`

Function-local settings:

  *  `SET search_path TO xeno, public, pg_temp`
  *  `SET pg_xenophile.in_l10n_table_event_trigger TO true`

#### Function: `l10n_table__track_drop_table_events()`

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

#### Function: `pg_xenophile_base_lang_code()`

Function return type: `lang_code_alpha2`

Function attributes: `STABLE`, `LEAKPROOF`

Function-local settings:

  *  `SET pg_readme.include_this_routine_definition TO true`
  *  `SET search_path TO xeno, public, pg_temp`

```sql
CREATE OR REPLACE FUNCTION xeno.pg_xenophile_base_lang_code()
 RETURNS lang_code_alpha2
 LANGUAGE sql
 STABLE LEAKPROOF
 SET "pg_readme.include_this_routine_definition" TO 'true'
 SET search_path TO 'xeno', 'public', 'pg_temp'
RETURN (COALESCE(current_setting('app.settings.i18n.base_lang_code'::text, true), current_setting('pg_xenophile.base_lang_code'::text, true), 'en'::text))::lang_code_alpha2
```

#### Function: `pg_xenophile_meta_pgxn()`

Returns the JSON meta data that has to go into the `META.json` file needed for PGXN—PostgreSQL Extension Network—packages.

The `Makefile` includes a recipe to allow the developer to: `make META.json` to
refresh the meta file with the function's current output, including the
`default_version`.

And indeed, `pg_xenophile` can be found on PGXN:
https://pgxn.org/dist/pg_xenophile/

Function return type: `jsonb`

Function attributes: `STABLE`

#### Function: `pg_xenophile_readme()`

Generates a README in Markdown format using the amazing power of the `pg_readme` extension.

Temporarily installs `pg_readme` if it is not already installed in the current database.

Function return type: `text`

Function-local settings:

  *  `SET search_path TO xeno, public, pg_temp`
  *  `SET pg_readme.include_view_definitions TO true`
  *  `SET pg_readme.include_routine_definitions_like TO {test__%}`

#### Function: `pg_xenophile_target_lang_codes()`

Function return type: `lang_code_alpha2[]`

Function attributes: `STABLE`, `LEAKPROOF`

Function-local settings:

  *  `SET pg_readme.include_this_routine_definition TO true`
  *  `SET search_path TO xeno, public, pg_temp`

```sql
CREATE OR REPLACE FUNCTION xeno.pg_xenophile_target_lang_codes()
 RETURNS lang_code_alpha2[]
 LANGUAGE sql
 STABLE LEAKPROOF
 SET "pg_readme.include_this_routine_definition" TO 'true'
 SET search_path TO 'xeno', 'public', 'pg_temp'
RETURN (COALESCE(current_setting('app.settings.i18n.target_lang_codes'::text, true), current_setting('pg_xenophile.target_lang_codes'::text, true), '{}'::text))::lang_code_alpha2[]
```

#### Function: `pg_xenophile_user_lang_code()`

Function return type: `lang_code_alpha2`

Function attributes: `STABLE`, `LEAKPROOF`

Function-local settings:

  *  `SET pg_readme.include_this_routine_definition TO true`
  *  `SET search_path TO xeno, public, pg_temp`

```sql
CREATE OR REPLACE FUNCTION xeno.pg_xenophile_user_lang_code()
 RETURNS lang_code_alpha2
 LANGUAGE sql
 STABLE LEAKPROOF
 SET "pg_readme.include_this_routine_definition" TO 'true'
 SET search_path TO 'xeno', 'public', 'pg_temp'
RETURN (COALESCE(current_setting('app.settings.i18n.user_lang_code'::text, true), current_setting('pg_xenophile.user_lang_code'::text, true), regexp_replace(current_setting('lc_messages'::text), '^([a-z]{2}).*$'::text, ''::text), 'en'::text))::lang_code_alpha2
```

#### Function: `set_installed_extension_version_from_name()`

Sets the installed extension version string in the column named in the second argument for the extension named in the second argument.

See the [`test__set_installed_extension_version_from_name()` test
procedure](#procedure-test__set_installed_extension_version_from_name) for a
working example of this trigger function.

This function was lifted from the `pg_utility_trigger_functions` extension
version. 1.4.0, by means of copy-paste to keep the number of inter-extension
dependencies to a minimum.

Function return type: `trigger`

Function-local settings:

  *  `SET search_path TO xeno, public, pg_temp`

#### Procedure: `test_dump_restore__l10n_table (text)`

This procedure is to be called by the `test_dump_restore.sh` and `test_dump_restore.sql` companion scripts, once before `pg_dump` (with `test_stage$ = 'pre-dump'` argument) and once after `pg_restore` (with the `test_stage$ = 'post-restore'`).

Procedure arguments:

| Arg. # | Arg. mode  | Argument name                                                     | Argument type                                                        | Default expression  |
| ------ | ---------- | ----------------------------------------------------------------- | -------------------------------------------------------------------- | ------------------- |
|   `$1` |       `IN` | `test_stage$`                                                     | `text`                                                               |  |

Procedure-local settings:

  *  `SET search_path TO xeno, public, pg_temp`
  *  `SET plpgsql.check_asserts TO true`

```sql
CREATE OR REPLACE PROCEDURE xeno.test_dump_restore__l10n_table(IN "test_stage$" text)
 LANGUAGE plpgsql
 SET search_path TO 'xeno', 'public', 'pg_temp'
 SET "plpgsql.check_asserts" TO 'true'
AS $procedure$
declare
    _en_expected record;
    _nl_expected record;
    _pt_expected record;
    _es_expected record;
    _en_actual record;
    _nl_actual record;
    _pt_actual record;
    _es_actual record;
begin
    assert test_stage$ in ('pre-dump', 'post-restore');

    if test_stage$ = 'pre-dump' then
        -- Create the table that will be translated.
        create table test_uni (
            uni_abbr text
                primary key
        );

        insert into l10n_table
            (base_table_name, l10n_column_definitions, base_lang_code, target_lang_codes)
        values (
            'test_uni'
            ,array['name TEXT NOT NULL']
            ,'en'::lang_code_alpha2
            ,array['nl', 'fr']::lang_code_alpha2[]
        );

        assert to_regclass('test_uni_l10n') is not null,
            'The `_l10n` table should have been created as result of the preceding INSERT into the meta table.';
    end if;

    -- Set up the expected data, now that we for sure have the `test_uni_l10n_*` types,
    -- regardless of `test_stage$`.
    _en_expected := row('AX-UNI', 'en', 'Axe University')::test_uni_l10n_en;
    _nl_expected := row('AX-UNI', 'nl', 'Bijl Universiteit')::test_uni_l10n_nl;

    if test_stage$ = 'pre-dump' then
        insert into test_uni_l10n_en
            (uni_abbr, name)
        values
            (_en_expected.uni_abbr, _en_expected.name)
        returning
            *
        into
            _en_actual
        ;
        update
            test_uni_l10n_nl
        set
            name = _nl_expected.name
        where
            uni_abbr = _en_expected.uni_abbr
        returning
            *
        into
            _nl_actual
        ;
    elsif test_stage$ = 'post-restore' then
        select * into _en_actual from test_uni_l10n_en where uni_abbr = _en_expected.uni_abbr;
        select * into _nl_actual from test_uni_l10n_nl where uni_abbr = _nl_expected.uni_abbr;
    end if;

    assert _en_expected = _en_actual;
    assert _nl_expected = _nl_actual;

    --
    -- Go test a dependent extension (that has its own `l10n_table`) now…
    --

    if test_stage$ = 'pre-dump' then
        create extension l10n_table_dependent_extension;
    end if;

    _pt_expected := row(
        '👋'
        ,10
        ,false
        ,'pt'
        ,null
        ,null
        ,'tchau'
    )::subextension_tbl_l10n_pt;
    _es_expected := row(
        '👋'
        ,10
        ,false
        ,'es'
        ,null
        ,null
        ,'adiós'
    )::subextension_tbl_l10n_es;

    if test_stage$ = 'pre-dump' then
        insert into subextension_tbl_l10n_pt
            (natural_key, base_tbl_col, localized_text)
        values
            (_pt_expected.natural_key, _pt_expected.base_tbl_col, _pt_expected.localized_text)
        returning
            *
        into
            _pt_actual
        ;
        update
            subextension_tbl_l10n_es
        set
            localized_text = _es_expected.localized_text
        where
            natural_key = _es_expected.natural_key
        returning
            *
        into
            _es_actual
        ;
    elsif test_stage$ = 'post-restore' then
        select * into _pt_actual from subextension_tbl_l10n_pt where natural_key = _pt_expected.natural_key;
        select * into _es_actual from subextension_tbl_l10n_es where natural_key = _es_expected.natural_key;
    end if;

    assert _pt_actual = _pt_expected,
        format('%s != %s', _pt_actual, _pt_expected);
    assert _es_actual = _es_expected,
        format('%s != %s', _es_actual, _es_expected);

    --
    -- Test with the dependent subextension and a Portuguese row that has been inserted during installation…
    --

    _pt_expected := row(
        '👍'
        ,null
        ,true
        ,'pt'
        ,'l10n_table_dependent_extension'
        ,'forever'  -- Yes, this is a version string.
        ,'bem'
    )::subextension_tbl_l10n_pt;
    _es_expected := row(
        '👍'
        ,null
        ,true
        ,'es'
        ,null
        ,null
        ,'buen'
    )::subextension_tbl_l10n_es;

    if test_stage$ = 'pre-dump' then
        select * into _pt_actual from subextension_tbl_l10n_pt where natural_key = _pt_expected.natural_key;
        update
            subextension_tbl_l10n_es
        set
            localized_text = _es_expected.localized_text
        where
            natural_key = _es_expected.natural_key
        returning
            *
        into
            _es_actual
        ;
    elsif test_stage$ = 'post-restore' then
        select * into _pt_actual from subextension_tbl_l10n_pt where natural_key = _pt_expected.natural_key;
        select * into _es_actual from subextension_tbl_l10n_es where natural_key = _es_expected.natural_key;
    end if;

    assert _pt_actual = _pt_expected,
        format('%s != %s', _pt_actual, _pt_expected);
    assert _es_actual = _es_expected,
        format('%s != %s', _es_actual, _es_expected);
end;
$procedure$
```

#### Procedure: `test__l10n_table()`

Procedure-local settings:

  *  `SET search_path TO xeno, public, pg_temp`
  *  `SET client_min_messages TO WARNING`
  *  `SET plpgsql.check_asserts TO true`
  *  `SET pg_readme.include_this_routine_definition TO true`

```sql
CREATE OR REPLACE PROCEDURE xeno.test__l10n_table()
 LANGUAGE plpgsql
 SET search_path TO 'xeno', 'public', 'pg_temp'
 SET client_min_messages TO 'WARNING'
 SET "plpgsql.check_asserts" TO 'true'
 SET "pg_readme.include_this_routine_definition" TO 'true'
AS $procedure$
declare
    _row record;
    _l10n_table l10n_table;
begin
    -- Create the table that will be translated.
    create table test_uni (
        id bigint
            primary key
            generated always as identity
        ,uni_abbr text
            not null
            unique
        -- We need to have more than one non-PK column, to ensure that we're hitting the requirement to agg.
        -- Also, let's put a space in the column name, so that we're testing proper quoting as well.
        ,"student rating" bigint
            default 5
    );

    <<with_redundant_target_lang>>
    begin
        -- This tests that the trigger(s) on `l10n_table` tries to create the `_l10n_nl`-suffixed view
        -- only once and doesn't crash because of trying to create it twice.
        insert into l10n_table
            (base_table_name, l10n_column_definitions, base_lang_code, target_lang_codes)
        values (
            'test_uni'
            ,array['name TEXT NOT NULL', '"description (short)" TEXT NOT NULL']
            ,'nl'::lang_code_alpha2  -- Apologies for the Dutch East India Company mentality.
            ,array['nl']::lang_code_alpha2[]
        );
        raise transaction_rollback;
    exception
        when transaction_rollback then
    end with_redundant_target_lang;

    -- Register `test_uni` with the meta table, to activate all the l10n magic.
    insert into l10n_table
        (base_table_name, l10n_column_definitions, base_lang_code, target_lang_codes)
    values (
        'test_uni'
        ,array['name TEXT NOT NULL', '"description (short)" TEXT NOT NULL']
        ,'nl'::lang_code_alpha2  -- Apologies for the Dutch East India Company mentality.
        ,array['en', 'fr']::lang_code_alpha2[]
    );

    assert to_regclass('test_uni_l10n') is not null,
        'The `_l10n` table should have been created as result of the preceding INSERT into the meta table.';

    assert (
            select
                array_agg(pg_class.relname order by pg_class.relname)::name[]
            from
                pg_catalog.pg_class
            where
                pg_class.relkind = 'v'
                and pg_class.relnamespace = current_schema::regnamespace
                and pg_class.relname like 'test\_uni\_l10n\___'
        ) = array['test_uni_l10n_en', 'test_uni_l10n_fr', 'test_uni_l10n_nl']::name[]
        ,'3 `_l10n_<lang_code>`-suffixed views should have been created, one for the base language'
            || ' and 2 for the target languages.';

    <<upsert_into_l10n_lang_view>>
    declare
        _nl_expected record := row(
            1, 'AX-UNI', 5, 'nl', 'Bijl Universiteit', 'De trainingsleider in bijlonderhoud en gebruik'
        )::test_uni_l10n_nl;
        _en_expected record := row(
            1, 'AX-UNI', 5, 'en', 'Axe University', 'The leader in axe maintenance and usage training'
        )::test_uni_l10n_en;
    begin
        insert into test_uni_l10n_nl
            (uni_abbr, name, "description (short)")
        values
            (_nl_expected.uni_abbr, _nl_expected.name, _nl_expected."description (short)")
        returning
            *
        into
            _row
        ;

        assert _row = _nl_expected, format(
            'The `RETURNING` clause did not return the data as inserted; %s ≠ %s'
            ,_row, _nl_expected
        );

        assert _nl_expected = (select row(tbl.*)::test_uni_l10n_nl from test_uni_l10n_nl as tbl),
            'The `RETURNING` clause should have returned the same row data as this separate `SELECT`.';

        assert exists(select from test_uni_l10n_en where id = _nl_expected.id),
            'Even though the row for English doesn''t exist in `test_uni_l10n` yet, it should exist in the'
            ' `test_l10n_en` view, with NULL values for all the l10n columns.';

        update
            test_uni_l10n_en
        set
            "name" = _en_expected."name"
            ,"description (short)" = _en_expected."description (short)"
        where
            id = _nl_expected.id
        returning
            *
        into
            _row
        ;

        assert found, 'The `UPDATE` should have found a row to update in the `test_uni_l10n_en` view.';

        assert _row = _en_expected,
            format('%s ≠ %s; the `RETURNING` clause did not return the data as upserted.', _row, _en_expected);

        assert _en_expected = (select row(tbl.*)::test_uni_l10n_en from test_uni_l10n_en as tbl),
            'The `RETURNING` clause should have returned the same row data as this separate `SELECT`.';
    end upsert_into_l10n_lang_view;

    <<try_to_override_generated_pk>>
    declare
        _expected_id bigint := currval('test_uni_id_seq') + 1;
        _nl_expected record := row(
            _expected_id, 'SIMP-UNI', 2, 'nl', 'Simpschool', 'Simpen voor Elon en Jeff'
        )::test_uni_l10n_nl;
    begin
        insert into test_uni_l10n_nl
            (id, uni_abbr, "student rating", name, "description (short)")
        values (
            _nl_expected.id
            ,_nl_expected.uni_abbr
            ,_nl_expected."student rating"
            ,_nl_expected.name
            ,_nl_expected."description (short)"
        )
        returning
            *
        into
            _row
        ;

        raise assert_failure using
            message = 'It should not be possible to explicitly specify a PK value on insert'
                'if that PK is `GENERATED ALWAYS`.';
    exception
        when generated_always then
    end try_to_override_generated_pk;

    <<insert_instead_of_update_on_missing_l10n_record>>
    declare
        _expected_id bigint := currval('test_uni_id_seq') + 1;
        _nl_expected record := row(
            _expected_id, 'PO-UNI', 7, 'nl', 'Poep-Universiteit', 'De Beste Plek om Te Leren Legen'
        )::test_uni_l10n_nl;
        _en_expected record := row(
            _expected_id, 'PO-UNI', 7, 'en', 'Pooversity', 'The Best Place To Empty Yourself'
        )::test_uni_l10n_nl;
    begin
        insert into test_uni_l10n_nl
            (uni_abbr, "student rating", name, "description (short)")
        values (
            _nl_expected.uni_abbr
            ,_nl_expected."student rating"
            ,_nl_expected.name
            ,_nl_expected."description (short)"
        )
        returning
            *
        into
            _row
        ;

        -- Test that the trigger `test_uni_l10n_en` does an INSERT instead of an UPDATE if no row for this
        -- PK + lang_code combo exists yet in `test_uni_l10n`.
        update
            test_uni_l10n_en
        set
            uni_abbr = _en_expected.uni_abbr
            ,name = _en_expected.name
            ,"description (short)" = _en_expected."description (short)"
        where
            id = _en_expected.id
        returning
            *
        into
            _row
        ;

        assert _row = _en_expected, format('%s ≠ %s', _row, _en_expected);
    end insert_instead_of_update_on_missing_l10n_record;

    <<delete_via_l10n_view>>
    declare
        _expected_id bigint := currval('test_uni_id_seq') + 1;
        _fr_expected record := row(
            _expected_id, 'MOI-UNI', null, 'fr', 'Moiversitee', 'La Premier Bla'
        )::test_uni_l10n_fr;
    begin
        insert into test_uni_l10n_fr
            (uni_abbr, name, "description (short)")
        values
            (_fr_expected.uni_abbr, _fr_expected.name, _fr_expected."description (short)")
        returning
            *
        into
            _row
        ;
        delete from test_uni_l10n_fr where id = _row.id;
        assert found;
        assert not exists (select from test_uni where id = _row.id),
            'The base table record should have been deleted.';
        assert not exists (
                select from test_uni_l10n where id = _row.id and l10n_lang_code = _row.l10n_lang_code
            )
            ,'The l10n record should have been deleted, via the `ON DELETE CASCADE` to the base table.';
    end delete_via_l10n_view;

    <<trigger_alter_table_events>>
    begin
        alter table test_uni_l10n
            add description2 text;

        update test_uni_l10n
            set description2 = 'Something to satisfy NOT NULL';  -- Because we want to make it NOT NULL.

        alter table test_uni_l10n
            alter column description2 set not null;

        select * into _l10n_table from l10n_table where base_table_name = 'test_uni';

        assert _l10n_table.l10n_column_definitions[3] = 'description2 text NOT NULL',
            'The `l10n_table__track_alter_table_events` event trigger should have updated the list of l10n'
            ' columns.';

        assert exists(
                select
                from    pg_attribute
                where   attrelid = 'test_uni_l10n_fr'::regclass
                        and attname = 'description2'
            ), 'The `description2` column should have been added to the view.';

        alter table test_uni_l10n
            drop column description2
            cascade;

        select * into _l10n_table from l10n_table where base_table_name = 'test_uni';

        assert array_length(_l10n_table.l10n_column_definitions, 1) = 2,
            'The dropped column should have been removed from the `l10n_table` meta table.';

        assert not exists(
                select
                from    pg_attribute
                where   attrelid = 'test_uni_l10n_nl'::regclass
                        and attname = 'description2'
            ), 'The `description2` column should have disappeared from the views.';

        alter table test_uni
            add non_l10n_col int
                not null
                default 6;

        select * into _l10n_table from l10n_table where base_table_name = 'test_uni';

        assert _l10n_table.base_column_definitions[4] = 'non_l10n_col integer NOT NULL DEFAULT 6',
            'The `l10n_table__track_alter_table_events` event trigger should have updated the list of base'
            ' columns.';

        assert (select non_l10n_col from test_uni_l10n_nl where id = 2) = 6;

        alter table test_uni
            drop column non_l10n_col
            cascade;

        assert not exists(
                select
                from    pg_attribute
                where   attrelid = 'test_uni_l10n_nl'::regclass
                        and attname = 'non_l10n_col'
            ), 'The `non_l10n_col` column should have disappeared from the views.';

        <<add_base_column_with_default_value>>
        declare
            _nl_expected record;
        begin
            alter table test_uni
                add column base_col_with_default text
                    not null
                    default 'I am default.';

            alter table test_uni_l10n
                add column localized_image text
                    not null
                    default 'fallback.png';

            select * into _l10n_table from l10n_table where base_table_name = 'test_uni';

            assert _l10n_table.base_column_definitions[4]
                    = 'base_col_with_default text NOT NULL DEFAULT ''I am default.''::text',
                format(
                    'The `l10n_table__track_alter_table_events` event trigger should have updated the list of'
                    ' base columns; base_column_definitions = ''%s'''
                    ,_l10n_table.base_column_definitions
                );

            assert _l10n_table.l10n_column_definitions[3]
                    = 'localized_image text NOT NULL DEFAULT ''fallback.png''::text',
                format(
                    'The `l10n_table__track_alter_table_events` event trigger should have updated the list of'
                    ' l10n columns; l10n_column_definitions = ''%s'''
                    ,_l10n_table.l10n_column_definitions
                );

            -- Now, let's test how the defaults behave on insert…

            _nl_expected := row(
                1, 'HOF', 5, 'I am default.', 'nl', 'Wim Hof', 'De Ijsman', 'fallback.png'
            )::test_uni_l10n_nl;

            insert into test_uni_l10n_nl
                (uni_abbr, name, "description (short)")
            values
                (_nl_expected.uni_abbr, _nl_expected.name, _nl_expected."description (short)")
            returning
                *
            into
                _row
            ;

            assert _row.base_col_with_default = _nl_expected.base_col_with_default,
                'Default should have propegated from the base table to view.';
            assert _row.localized_image = _nl_expected.localized_image,
                'Default should have propegated from the l10n table to view.';
        end add_base_column_with_default_value;

        <<drop_base_table>>
        begin
            drop table test_uni cascade;

            assert not exists (select from l10n_table where base_table_name = 'test_uni');

            raise transaction_rollback;  -- I could have used any error code, but this one seemed to fit best.
        exception
            when transaction_rollback then
        end drop_base_table;
    end trigger_alter_table_events;

    -- DELETE-ing the meta info for our l10n table should cascade cleanly, without crashing.
    delete from l10n_table where base_table_regclass = 'test_uni'::regclass;

    assert to_regclass('test_uni_l10n') is null,
        'The actual `_l10n` table should have been removed when deleting the meta row from `l10n_table`.';

    <<insert_natural_key>>
    declare
        _expected record;
    begin
        -- Let's make a table with a natural primary key that is _not_ `GENERATED ALWAYS`.
        create table test_species (
            scientific_name text
                primary key
            -- Just so you know: without the `year_first_described` column, the `INSERT INTO l10n_table`
            -- would not trigger a certain bug, so please do not allow regressions to occur by removing
            -- this column.
            ,year_first_described int
        );

        -- Register `test_species` with the meta table, to activate all the l10n magic.
        insert into l10n_table
            (base_table_name, l10n_column_definitions, base_lang_code)
        values
            ('test_species' ,'{common_name TEXT}' ,'en')
        ;

        insert into test_species_l10n_en
            (scientific_name, common_name, year_first_described)
        values
            ('Taraxacum officinale', 'common dandelion', 1753)
        ;

        <<insert_duplicate_natural_key>>
        begin
            insert into test_species_l10n_en
                (scientific_name, common_name)
            values
                ('Taraxacum officinale', 'uncommon dandelion')
            ;
            raise assert_failure using message = 'Duplicating a primary key shouldn''t have been possible.';
        exception
            when unique_violation then
        end insert_duplicate_natural_key;
    end insert_natural_key;

    raise transaction_rollback;  -- I could have used any error code, but this one seemed to fit best.
exception
    when transaction_rollback then
end;
$procedure$
```

#### Function: `updatable_l10n_view()`

Function return type: `trigger`

Function-local settings:

  *  `SET search_path TO xeno, public, pg_temp`

### Types

The following extra types have been defined _besides_ the implicit composite types of the [tables](#tables) and [views](#views) in this extension.

#### Domain: `currency_code`

Using this domain instead of its underlying `text` type ensures that only uppercase, 3-letter currency codes are allowed.  It does _not_ enforce that the `currency_code` exists in the `currency` table.

```sql
CREATE DOMAIN currency_code AS text
  CHECK ((VALUE ~ '^[A-Z]{3}$'::text));
```

#### Domain: `country_code_alpha2`

Using this domain instead of its underlying `text` type ensures that only 2-letter, uppercase country codes are allowed.

```sql
CREATE DOMAIN country_code_alpha2 AS text
  CHECK ((VALUE ~ '^[A-Z]{2}$'::text));
```

#### Domain: `lang_code_alpha2`

ISO 639-1 two-letter (lowercase) language code.

```sql
CREATE DOMAIN lang_code_alpha2 AS text
  CHECK ((VALUE ~ '^[a-z]{2}$'::text));
```

#### Domain: `lang_code_alhpa3`

ISO 639-2/T, ISO 639-2/B, or ISO 639-3 (lowercase) language code.

```sql
CREATE DOMAIN lang_code_alhpa3 AS text
  CHECK ((VALUE ~ '^[a-z]{3}$'::text));
```

## Missing/planned/possible features

* Currently (as of version 0.7.4), only ISO 639-1 (2-letter) language codes are
  supported.  It would be nice if at least ISO 639-2 3-letter code would be
  supported, and possibly ISO 639-2/T and 639-2/B as well.  Even better would be
  if [BPC 47 / RFC 5646](https://datatracker.ietf.org/doc/html/rfc5646) was
  supported.  If I (Rowan) do change the primary language identification method,
  I will try to do so _before_ `pg_xenophile` 1.0 is released, because
  introducing breaking changes post-1.0 is assholish towards the couple of users
  that might by then already depend on this extension.

## Extension authors and contributors

* [Rowan](https://www.bigsmoke.us/) originated this extension in 2022 while
  developing the PostgreSQL backend for the [FlashMQ SaaS MQTT cloud
  broker](https://www.flashmq.com/).  Rowan does not like to see himself as a
  tech person or a tech writer, but, much to his chagrin, [he
  _is_](https://blog.bigsmoke.us/category/technology). Some of his chagrin
  about his disdain for the IT industry he poured into a book: [_Why
  Programming Still Sucks_](https://www.whyprogrammingstillsucks.com/).  Much
  more than a “tech bro”, he identifies as a garden gnome, fairy and ork rolled
  into one, and his passion is really to [regreen and reenchant his
  environment](https://sapienshabitat.com/).  One of his proudest achievements
  is to be the third generation ecological gardener to grow the wild garden
  around his beautiful [family holiday home in the forest of Norg, Drenthe,
  the Netherlands](https://www.schuilplaats-norg.nl/) (available for rent!).

## Colophon

This `README.md` for the `pg_xenophile` extension was automatically generated using the [`pg_readme`](https://github.com/bigsmoke/pg_readme) PostgreSQL extension.
