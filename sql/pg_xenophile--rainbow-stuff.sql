create or replace procedure mig.migration_xxxx_i18n_rainbow_stuff()
language plpgsql
as $migration_procedure$
<<migration>>
begin
    call mig.start_migration('1496cee6-e087-40ba-8305-5d70260b9701');

    ----------------------------------------------------------------------------------------------------------

    create table i18n.str_domain (
        str_domain name primary key
    );
    comment on table i18n.str_domain
        is 'Think of gettext domains, not SQL domains.';

    create table i18n.str (
        str_id uuid
        ,str text not null
        ,str_domain name not null
            references i18n.str_domain(str_domain)
        ,lang_alpha2 text
            references i18n.lang(alpha2)
        ,inserted_at timestamptz not null
            default now()
        ,updated_at timestamptz not null
            default now()
        ,primary key (str_id, str_domain, lang_alpha2)
        ,unique (str, str_domain, lang_alpha2)
    );

    create trigger update_updated_at
        before update on i18n.str_domain
        for each row
        execute function util.update_updated_at();

    create function i18n.str(
        str_id$ uuid
        ,str_domain$ name default current_setting('app.settings.i18n.str_domain', true)
        ,lang_alpha2$ i18n.lang_alpha2 default coalesce(
            current_setting('app.settings.i18n.user_lang_alpha2', true),
            current_setting('app.settings.i18n.base_lang_alpha2', false)
        )
    )
    returns text
    stable
    leakproof
    language sql
    return coalesce(
        (
            select
                str
            from
                i18n.str
            where
                str_id = str_id$
                and str_domain = str_domain$
                and lang_alpha2 = lang_alpha2$
        ),
        (
            select
                str
            from
                i18n.str
            where
                str_id = str_id$
                and str_domain = str_domain$
                and lang_alpha2 = current_setting('app.settings.i18n.base_lang_alpha2', false)
        )
    );

    create function i18n.str(
        str$ text
        ,str_domain$ name default current_setting('app.settings.i18n.str_domain', true)
        ,lang_alpha2$ i18n.lang_alpha2
            default current_setting('app.settings.i18n.base_lang_alpha2', false)
    )
    returns uuid
    stable
    language sql
    as $$
        insert into i18n.str (str, str_domain_code, lang_alpha2)
        values (
            str$
            ,str_domain$
            ,lang_alpha2$
        )
        on conflict do nothing
        returning str_id
        ;
    $$;

    create function i18n.str_l10n(
        str_domain$ name default current_setting('app.settings.i18n.str_domain', true)
        ,target_lang_alpha2$ i18n.lang_alpha2
        ,base_lang_alpha2$ i18n.lang_alpha2
            default current_setting('app.settings.i18n.base_lang_alpha2', false)
    )
    returns table (
        base_lang_alpha2 i18n.lang_alpha2
        ,base_str text
        ,str_id uuid
        ,str_domain name
        ,target_lang_alpha2 i18n.lang_alpha2
        ,target_str text
    )
    language sql
    as $$
        select
            base_lang_alpha2$
            ,base.str
            ,base.str_id
            ,str_domain$
            ,target_lang_alpha2$
            ,target.str
        from
            i18n.str as base
        left outer join
            i18n.str as target
            on target.str_id = base.str_id
            and target.str_domain = base.str_domain
        where
            base.lang_alpha2 = base_lang_alpha2$
            and target.lang_alpha2 = target_lang_alpha2$
            and base.str_domain = str_domain$
        ;
    $$;

    create procedure i18n.test__str_stuff()
    language plpgsql
    as $$
declare
begin
    set_config('app.settings.i18n.base_lang_alpha2', 'en', true),

    create table i18n.test_page (
        id int primary key
        ,title_str_id uuid
        ,summary_str_id uuid
    );

    insert into i18n.test_page (id, title_str_id, summary_str_id)
    values
        (1, i18n.str('First Page'), i18n.str('Because First Things should go first.')),
        (2, i18n.str('Second Page'), i18n.str('Second Things should go second.'));

    select
        tst.assert_equal(str(title_str_id), 'First Page')
        ,tst.assert_equal(str(dummary_str_id), 'Because First Things should go first.')
    from
        i18n.test_page
    where
        id = 1
    ;

    raise transaction_rollback;
exception
    when transaction_rollback then
end;
    $$;

    ----------------------------------------------------------------------------------------------------------

    create table i18n.l10n_table_column (
        table_schema name
        ,l10n_table name
        ,l10n_column name
    );

    ----------------------------------------------------------------------------------------------------------

    call mig.finish_migration();
end migration;
$migration_procedure$;
