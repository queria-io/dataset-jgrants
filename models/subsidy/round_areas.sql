{# 募集回の対象地域を 1 地域 1 行に分けたもの。原典の地域は 全国・47 都道府県・8 つの地方・海外 だけで、
   市区町村の補助金も都道府県で入っている。全国の補助金を都道府県で引くときは area_level = 'national' も足す。 #}

with prefectures(prefecture_code, prefecture) as (
    values
        ('01', '北海道'), ('02', '青森県'), ('03', '岩手県'), ('04', '宮城県'), ('05', '秋田県'),
        ('06', '山形県'), ('07', '福島県'), ('08', '茨城県'), ('09', '栃木県'), ('10', '群馬県'),
        ('11', '埼玉県'), ('12', '千葉県'), ('13', '東京都'), ('14', '神奈川県'), ('15', '新潟県'),
        ('16', '富山県'), ('17', '石川県'), ('18', '福井県'), ('19', '山梨県'), ('20', '長野県'),
        ('21', '岐阜県'), ('22', '静岡県'), ('23', '愛知県'), ('24', '三重県'), ('25', '滋賀県'),
        ('26', '京都府'), ('27', '大阪府'), ('28', '兵庫県'), ('29', '奈良県'), ('30', '和歌山県'),
        ('31', '鳥取県'), ('32', '島根県'), ('33', '岡山県'), ('34', '広島県'), ('35', '山口県'),
        ('36', '徳島県'), ('37', '香川県'), ('38', '愛媛県'), ('39', '高知県'), ('40', '福岡県'),
        ('41', '佐賀県'), ('42', '長崎県'), ('43', '熊本県'), ('44', '大分県'), ('45', '宮崎県'),
        ('46', '鹿児島県'), ('47', '沖縄県')
),

areas as (
    select distinct
        round_id,
        subsidy_id,
        trim(unnest(string_split(target_area, '/'))) as area_name
    from {{ ref('rounds') }}
    where target_area is not null
)

select
    areas.round_id,
    areas.subsidy_id,
    areas.area_name,
    case
        when areas.area_name = '全国' then 'national'
        when areas.area_name = '海外' then 'overseas'
        when prefectures.prefecture_code is not null then 'prefecture'
        when areas.area_name like '%地方' then 'region'
    end as area_level,
    prefectures.prefecture_code
from areas
left join prefectures on prefectures.prefecture = areas.area_name
where areas.area_name <> ''
