{# 補助金の募集回（J グランツの workflow）1 回 1 行。受付期間と対象地域は回ごとに違うことがある。 #}

select *
from {{ ref('stg_rounds') }}
