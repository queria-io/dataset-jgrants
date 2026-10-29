# dataset-jgrants

デジタル庁の補助金申請システム「Jグランツ」の補助金を Queria のカタログ（[data.queria.io](https://data.queria.io/)）へ取り込むデータセットです。

## データ出典

[Jグランツの公開 API](https://developers.digital.go.jp/documents/jgrants/api/)（認証なし）の補助金一覧と補助金詳細（V2）を表にします。

| 原典 | テーブル |
| --- | --- |
| 補助金詳細 V2 の JSON（添付はファイル名だけ） | `subsidy.details` |
| 補助金詳細 V2 | `subsidy.subsidies` |
| 補助金詳細 V2 の `workflow` | `subsidy.rounds` |
| `workflow` の `target_area_search` | `subsidy.round_areas` |

使うときは「出典：Jグランツ」と、加工したものであることを書いてください（Jグランツの Web-API 利用規約）。内容は国・自治体が保証するものではありません。申請の前に各補助金の Jグランツのページ（`portal_url`）で公式の情報を確かめてください。

## 収録テーブル

| テーブル | 内容 |
| --- | --- |
| `subsidy.subsidies` | 1 行が 1 補助金。名前・概要・利用目的・業種・補助率・補助上限額。受付が終わったものも残る |
| `subsidy.rounds` | 1 行が 1 補助金の 1 募集回。受付期間・事業完了期限（タイムゾーン付き）・対象地域 |
| `subsidy.round_areas` | 1 行が 1 募集回の 1 地域。都道府県には都道府県コード |
| `subsidy.details` | 原典の詳細 JSON。表にない項目を見るときと、毎日の差分取得に使う |

- 国の補助金と、Jグランツで申請を受ける自治体の補助金が入る。Jグランツを使わない自治体の補助金は入らない
- 対象地域は 全国・47 都道府県・8 つの地方・海外 だけ。市区町村の補助金も都道府県で入っていて、市区町村はタイトル先頭の【】にしか出てこず、取れたものを `title_municipality` に入れた（80 件）
- 公募要領・交付要綱・申請様式は本体を持たず、ファイル名だけ持つ

```sql
-- いま東京都で受け付けている補助金
SELECT s.title, s.subsidy_max_limit, s.subsidy_rate, r.acceptance_end_at, s.portal_url
FROM jgrants.subsidy.rounds AS r
JOIN jgrants.subsidy.subsidies AS s USING (subsidy_id)
WHERE r.acceptance_start_at <= now() AND now() < r.acceptance_end_at
  AND r.round_id IN (
    SELECT round_id FROM jgrants.subsidy.round_areas
    WHERE prefecture_code = '13' OR area_level = 'national'
  )
ORDER BY r.acceptance_end_at;
```

## 取得のしかた

一覧 API は 2 文字以上の `keyword` が必須で、全件を返す呼び方がありません。広い語を十数個投げて補助金 ID で重ねています（2026 年 10 月 29 日に 3,845 件）。漏れはありえます。

詳細には添付の本体が base64 で入っていて、1 件 4KB〜11MB あります。毎回全件取り直すと数 GB になるので、前回公開した `subsidy.details` を読み、一覧の行が変わった補助金と、受付中で 7 日以上取り直していない補助金だけ詳細を取ります。詳細は 1 秒おきに取ります。

## ビルド

```bash
git submodule update --init
uv sync
scripts/build.sh                    # queria sync -- python main.py
JGRANTS_REFETCH=1 scripts/build.sh  # 詳細を全件取り直す（2 時間ほど）
```

毎日 04:00（日本時間）に Sync が回ります。
