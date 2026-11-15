{# J グランツの補助金詳細（V2）をそのまま 1 補助金 1 行で持つ。添付は base64 を捨ててファイル名だけ。
   次の取得（pipelines/jgrants.py）はこの表を読んで差分だけ取る。 #}

select
    id,
    fingerprint,
    fetched_at,
    list_json,
    detail_json
from {{ ref('stg_details') }}
