{# 補助金詳細 1 補助金 1 行。原典の JSON を文字列のまま持つ（details で公開し、次の取得が差分を取るのに読む） #}

select
    id,
    fingerprint,
    fetched_at,
    list_json,
    detail_json
from {{ ref('raw_details') }}
