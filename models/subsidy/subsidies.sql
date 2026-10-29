{# 補助金 1 件 1 行。募集回ごとの受付期間と地域は rounds と round_areas。 #}

with details as (
    select id, cast(detail_json as json) as j, fetched_at
    from {{ ref('details') }}
),

files as (
    select
        *,
        from_json(j -> 'application_guidelines', '["VARCHAR"]') as guideline_files,
        from_json(j -> 'outline_of_grant', '["VARCHAR"]') as outline_files,
        from_json(j -> 'application_form', '["VARCHAR"]') as form_files
    from details
)

select
    id as subsidy_id,
    j ->> 'name' as subsidy_number,
    j ->> 'title' as title,
    -- タイトル先頭の【福岡県宗像市】。市区町村は API の地域に無く、ここにしか出ない。
    -- 【】には府省名や年度も入るので、市区町村で終わるものだけ取る。「能登地区」のような地区は市区町村ではない
    nullif(regexp_extract(j ->> 'title', '^【([^】]*(?:[市町村]|[^地]区))】', 1), '') as title_municipality,
    j ->> 'subsidy_catch_phrase' as catch_phrase,
    j ->> 'detail' as detail_html,
    trim(regexp_replace(
        replace(replace(replace(replace(replace(
            regexp_replace(
                regexp_replace(j ->> 'detail', '<br\s*/?>|</p>|</li>', chr(10), 'gi'),
                '<[^>]+>', '', 'g'
            ),
            '&nbsp;', ' '), '&lt;', '<'), '&gt;', '>'), '&quot;', '"'), '&amp;', '&'),
        '\n{3,}', chr(10) || chr(10), 'g'
    ), ' ' || chr(10)) as detail_text,
    -- 原典は「 / 」でつないだ文字列。全業種・全目的は全部の区分を並べてある
    string_split(nullif(j ->> 'use_purpose', ''), ' / ') as use_purposes,
    string_split(nullif(j ->> 'industry', ''), ' / ') as industries,
    j ->> 'target_number_of_employees' as target_number_of_employees,
    j ->> 'subsidy_rate' as subsidy_rate,
    try_cast(j ->> 'subsidy_max_limit' as bigint) as subsidy_max_limit,
    case j ->> 'request_reception_presence' when '有' then true when '無' then false end as request_reception,
    try_cast(j ->> 'is_enable_multiple_request' as boolean) as multiple_requests_allowed,
    j ->> 'granttype' as grant_type,
    -- 原典の institution_name。中身は実施機関ではなく事業名
    j ->> 'institution_name' as program_name,
    j ->> 'front_subsidy_detail_page_url' as portal_url,
    guideline_files,
    outline_files,
    form_files,
    cast(fetched_at as timestamptz) as fetched_at
from files
