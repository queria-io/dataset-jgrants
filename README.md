# Jグランツ 補助金

デジタル庁の補助金申請システム「Jグランツ」に載っている補助金を、SQL で検索・集計できるテーブルにしたデータセットです。国の補助金と、Jグランツで申請を受ける自治体の補助金を、受付が終わったものも含めて収録し、毎日更新します。

## 出典と利用条件

[Jグランツの公開 API](https://developers.digital.go.jp/documents/jgrants/api/)（デジタル庁）から補助金一覧と補助金詳細（V2）を取得して加工しています。

- 使うときは「出典：Jグランツ」と、加工したものであることを明記してください（Jグランツの Web-API 利用規約）
- 内容は国・自治体が保証するものではありません。申請の前に、各補助金の Jグランツのページ（`portal_url`）で公式の情報を確認してください

## テーブル

| テーブル | 内容 |
| --- | --- |
| `subsidy.subsidies` | 1 行が 1 補助金。名前・概要・利用目的・業種・補助率・補助上限額 |
| `subsidy.rounds` | 1 行が 1 補助金の 1 募集回。受付期間・事業完了期限・対象地域 |
| `subsidy.round_areas` | 1 行が 1 募集回の 1 地域。都道府県の行には都道府県コード |
| `subsidy.details` | 補助金詳細 API の JSON。上のテーブルにない項目を見るときに使います |

受付期間と対象地域は募集回ごとに異なることがあるため、`subsidies` ではなく `rounds` と `round_areas` に持たせています。多くの補助金は募集回が 1 つですが、地域ブロックごとに募集する補助金は複数の募集回を持ちます。

## 使い方

いま東京都で受け付けている補助金:

```sql
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

製造業が使える補助金（`industries` と `use_purposes` は配列です）:

```sql
SELECT title, subsidy_rate, subsidy_max_limit
FROM jgrants.subsidy.subsidies
WHERE list_contains(industries, '製造業');
```

全業種・全目的が対象の補助金は、すべての区分を配列に並べています。そのため、ある業種で使える補助金は `list_contains` だけで検索できます。

## 収録範囲の注意

- Jグランツで申請を受けない自治体の補助金は含みません
- 対象地域は全国・47 都道府県・8 地方・海外だけです。市区町村の補助金も原典では都道府県で登録されていて、市区町村はタイトル先頭の【】にしか出てきません。市区町村名で終わる【】は `title_municipality` に抜き出しています
- 補助上限額（`subsidy_max_limit`）の 0 は、上限なしか未記入です。原典では区別できません
- 公募要領・交付要綱・申請様式は本体を持たず、ファイル名だけを持ちます。本体は `portal_url` のページから取得してください
- 原典に 3026 年のような入力誤りがあるため、2100 年より後の日時は NULL にしています

## 取得方法

一覧 API は 2 文字以上の `keyword` が必須で、全件を返す呼び出し方がありません。広い語を十数個指定して補助金 ID で重ね合わせています（2026 年 10 月 29 日時点で 3,845 件）。取得漏れの可能性があります。

詳細には添付の本体が base64 で入っていて、1 件 4KB〜11MB あります。毎回全件を取得し直すと数 GB になるため、前回公開した `subsidy.details` を読み、一覧の行が変わった補助金と、受付中で 7 日以上取得し直していない補助金だけ詳細を取得します。詳細は 1 秒間隔で取得します。

## ビルド

```bash
git submodule update --init
uv sync
scripts/build.sh                    # queria sync -- python main.py
JGRANTS_REFETCH=1 scripts/build.sh  # 詳細を全件取得し直す（2 時間ほど）
```

毎日 04:00（日本時間）に Sync が実行されます。
