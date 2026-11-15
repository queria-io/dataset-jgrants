{# 補助金 1 件 1 行。募集回ごとの受付期間と地域は rounds と round_areas。 #}

select *
from {{ ref('stg_subsidies') }}
