{# J グランツの補助金詳細（V2）をそのまま 1 補助金 1 行で持つ。添付は base64 を捨ててファイル名だけ。
   pipelines/jgrants.py が data/jgrants/details.ndjson に書き出し、次の取得はこの表を読んで差分だけ取る。 #}

select
    id,
    fingerprint,
    fetched_at,
    list_json,
    detail_json
from read_json(
    'data/jgrants/details.ndjson',
    format = 'newline_delimited',
    columns = {
        id: 'VARCHAR',
        fingerprint: 'VARCHAR',
        fetched_at: 'VARCHAR',
        list_json: 'VARCHAR',
        detail_json: 'VARCHAR'
    }
)
