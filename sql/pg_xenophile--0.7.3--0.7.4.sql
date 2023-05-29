-- Complain if script is sourced in `psql`, rather than via `CREATE EXTENSION`.
\echo Use "CREATE EXTENSION pg_xenophile" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

-- Add to-do section.
comment on extension pg_xenophile is $markdown$
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

<?pg-readme-reference?>

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

<?pg-readme-colophon?>

$markdown$;

--------------------------------------------------------------------------------------------------------------

-- Insert previously missing languages.
insert into lang_l10n_en
    (lang_code, "name", lang_belongs_to_pg_xenophile, l10n_columns_belong_to_extension_name)
select
    v.lang_code_iso_639_1
    ,v.lang_name_en_wikipedia_primary
    ,true
    ,'pg_xenophile'
from (
    values
        ('ab', 'Abkhazian')
        ,('aa', 'Afar')
        ,('af', 'Afrikaans')
        ,('ak', 'Akan')
        ,('sq', 'Albanian')
        ,('am', 'Amharic')
        ,('ar', 'Arabic')
        ,('an', 'Aragonese')
        ,('hy', 'Armenian')
        ,('as', 'Assamese')
        ,('av', 'Avaric')
        ,('ae', 'Avestan')
        ,('ay', 'Aymara')
        ,('az', 'Azerbaijani')
        ,('bm', 'Bambara')
        ,('ba', 'Bashkir')
        ,('eu', 'Basque')
        ,('be', 'Belarusian')
        ,('bn', 'Bengali')
        ,('bi', 'Bislama')
        ,('bs', 'Bosnian')
        ,('br', 'Breton')
        ,('bg', 'Bulgarian')
        ,('my', 'Burmese')
        ,('ca', 'Catalan')
        ,('ch', 'Chamorro')
        ,('ce', 'Chechen')
        ,('ny', 'Chichewa')
        ,('zh', 'Chinese')
        ,('cu', 'Church Slavonic')
        ,('cv', 'Chuvash')
        ,('kw', 'Cornish')
        ,('co', 'Corsican')
        ,('cr', 'Cree')
        ,('hr', 'Croatian')
        ,('cs', 'Czech')
        ,('da', 'Danish')
        ,('dv', 'Divehi')
        --,('nl', 'Dutch')
        ,('dz', 'Dzongkha')
        --,('en', 'English')
        ,('eo', 'Esperanto')
        ,('et', 'Estonian')
        ,('ee', 'Ewe')
        ,('fo', 'Faroese')
        ,('fj', 'Fijian')
        ,('fi', 'Finnish')
        --,('fr', 'French')
        ,('fy', 'Western Frisian')
        ,('ff', 'Fulah')
        ,('gd', 'Gaelic')
        ,('gl', 'Galician')
        ,('lg', 'Ganda')
        ,('ka', 'Georgian')
        ,('de', 'German')
        ,('el', 'Greek')
        ,('kl', 'Kalaallisut')
        ,('gn', 'Guarani')
        ,('gu', 'Gujarati')
        ,('ht', 'Haitian')
        ,('ha', 'Hausa')
        ,('he', 'Hebrew')
        ,('hz', 'Herero')
        ,('hi', 'Hindi')
        ,('ho', 'Hiri Motu')
        ,('hu', 'Hungarian')
        ,('is', 'Icelandic')
        ,('io', 'Ido')
        ,('ig', 'Igbo')
        ,('id', 'Indonesian')
        ,('ia', 'Interlingua')
        ,('ie', 'Interlingue')
        ,('iu', 'Inuktitut')
        ,('ik', 'Inupiaq')
        ,('ga', 'Irish')
        ,('it', 'Italian')
        ,('ja', 'Japanese')
        ,('jv', 'Javanese')
        ,('kn', 'Kannada')
        ,('kr', 'Kanuri')
        ,('ks', 'Kashmiri')
        ,('kk', 'Kazakh')
        ,('km', 'Central Khmer')
        ,('ki', 'Kikuyu')
        ,('rw', 'Kinyarwanda')
        ,('ky', 'Kirghiz')
        ,('kv', 'Komi')
        ,('kg', 'Kongo')
        ,('ko', 'Korean')
        ,('kj', 'Kuanyama')
        ,('ku', 'Kurdish')
        ,('lo', 'Lao')
        ,('la', 'Latin')
        ,('lv', 'Latvian')
        ,('li', 'Limburgan')
        ,('ln', 'Lingala')
        ,('lt', 'Lithuanian')
        ,('lu', 'Luba-Katanga')
        ,('lb', 'Luxembourgish')
        ,('mk', 'Macedonian')
        ,('mg', 'Malagasy')
        ,('ms', 'Malay')
        ,('ml', 'Malayalam')
        ,('mt', 'Maltese')
        ,('gv', 'Manx')
        ,('mi', 'Maori')
        ,('mr', 'Marathi')
        ,('mh', 'Marshallese')
        ,('mn', 'Mongolian')
        ,('na', 'Nauru')
        ,('nv', 'Navaho')
        ,('nd', 'North Ndebele')
        ,('nr', 'South Ndebele')
        ,('ng', 'Ndonga')
        ,('ne', 'Nepali')
        ,('no', 'Norwegian')
        ,('nb', 'Norwegian Bokmål')
        ,('nn', 'Norwegian Nynorsk')
        ,('ii', 'Sichuan Yi')
        ,('oc', 'Occitan')
        ,('oj', 'Ojibwa')
        ,('or', 'Oriya')
        ,('om', 'Oromo')
        ,('os', 'Ossetian')
        ,('pi', 'Pali')
        ,('ps', 'Pashto')
        ,('fa', 'Persian')
        ,('pl', 'Polish')
        --,('pt', 'Portuguese')
        ,('pa', 'Punjabi')
        ,('qu', 'Quechua')
        ,('ro', 'Romanian')
        ,('rm', 'Romansh')
        ,('rn', 'Rundi')
        ,('ru', 'Russian')
        ,('se', 'Northern Sami')
        ,('sm', 'Samoan')
        ,('sg', 'Sango')
        ,('sa', 'Sanskrit')
        ,('sc', 'Sardinian')
        ,('sr', 'Serbian')
        ,('sn', 'Shona')
        ,('sd', 'Sindhi')
        ,('si', 'Sinhala')
        ,('sk', 'Slovak')
        ,('sl', 'Slovenian')
        ,('so', 'Somali')
        ,('st', 'Southern Sotho')
        --,('es', 'Spanish')
        ,('su', 'Sundanese')
        ,('sw', 'Swahili')
        ,('ss', 'Swati')
        ,('sv', 'Swedish')
        ,('tl', 'Tagalog')
        ,('ty', 'Tahitian')
        ,('tg', 'Tajik')
        ,('ta', 'Tamil')
        ,('tt', 'Tatar')
        ,('te', 'Telugu')
        ,('th', 'Thai')
        ,('bo', 'Tibetan')
        ,('ti', 'Tigrinya')
        ,('to', 'Tonga')
        ,('ts', 'Tsonga')
        ,('tn', 'Tswana')
        ,('tr', 'Turkish')
        ,('tk', 'Turkmen')
        ,('tw', 'Twi')
        ,('ug', 'Uighur')
        ,('uk', 'Ukrainian')
        ,('ur', 'Urdu')
        ,('uz', 'Uzbek')
        ,('ve', 'Venda')
        ,('vi', 'Vietnamese')
        ,('vo', 'Volapük')
        ,('wa', 'Walloon')
        ,('cy', 'Welsh')
        ,('wo', 'Wolof')
        ,('xh', 'Xhosa')
        ,('yi', 'Yiddish')
        ,('yo', 'Yoruba')
        ,('za', 'Zhuang')
        ,('zu', 'Zulu')
    ) as v (lang_code_iso_639_1, lang_name_en_wikipedia_primary)
;

--------------------------------------------------------------------------------------------------------------
