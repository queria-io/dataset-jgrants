{# 補助金の募集回（J グランツの workflow）1 回 1 行。受付期間と対象地域は回ごとに違うことがある。
   日時は原典が UTC。秒の無い 2026-10-28T06:35Z の形と、秒とミリ秒のある形が混ざる。
   受付開始が 3026 年のような入力誤りがあるので、2100 年より後は NULL にする。 #}

with workflows as (
    select
        id as subsidy_id,
        unnest(from_json(cast(detail_json as json) -> 'workflow', '["JSON"]')) as w
    from {{ ref('details') }}
),

parsed as (
    select
        subsidy_id,
        w ->> 'id' as round_id,
        w ->> 'fiscal_year_round' as fiscal_year_round,
        nullif(w ->> 'target_area_search', '') as target_area,
        w ->> 'target_area_detail' as target_area_detail,
        {% for name in ['acceptance_start_datetime', 'acceptance_end_datetime', 'project_end_deadline'] %}
        try_strptime(w ->> '{{ name }}', ['%Y-%m-%dT%H:%MZ', '%Y-%m-%dT%H:%M:%SZ', '%Y-%m-%dT%H:%M:%S.%gZ']) as {{ name }}{{ "," if not loop.last }}
        {% endfor %}
    from workflows
)

select
    round_id,
    subsidy_id,
    fiscal_year_round,
    target_area,
    target_area_detail,
    {% for name, alias in [('acceptance_start_datetime', 'acceptance_start'), ('acceptance_end_datetime', 'acceptance_end'), ('project_end_deadline', 'project_end')] %}
    -- 日本時間に直す
    case when year({{ name }}) <= 2100 then {{ name }} + interval 9 hour end as {{ alias }}_at{{ "," if not loop.last }}
    {% endfor %}
from parsed
