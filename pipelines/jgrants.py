"""J グランツ（デジタル庁）の公開 API から補助金を取り出す。

一覧 API は keyword（2 文字以上）が必須で、全件を返す呼び方が無い。広い語を
いくつも投げて id で重ねる。acceptance=0 で受付が終わったものも返る。
一覧はページングが無く、1 回で該当する全件が返る。

詳細は V2 を使う。V1 は募集回（workflow）が複数ある補助金で、地域を連結し
日時を 1 回分しか持たないため。詳細には公募要領などの PDF が base64 で入っていて
1 件 4KB〜11MB あるので、ファイル名だけ残して中身は捨てる。

詳細を毎回全件取り直すと数 GB になる。前回公開した subsidy.details を読み、
一覧の行が変わっていない補助金は前回の詳細を使い回す。ただし受付中のものは
一覧に出ない項目（概要や添付）の差し替えを拾うため、7 日たったら取り直す。
一覧から消えた補助金も前回の行を残す。JGRANTS_REFETCH=1 で全件取り直す。

出力: data/jgrants/details.ndjson（1 行 = 1 補助金）

データソース: デジタル庁 J グランツ
https://developers.digital.go.jp/documents/jgrants/api/
"""

import hashlib
import json
import logging
import os
import time
from datetime import UTC, datetime, timedelta
from pathlib import Path
from urllib.parse import urlencode

from shared.fetch import fetch, replacing

logger = logging.getLogger("pipelines")

API = "https://api.jgrants-portal.go.jp/exp"
USER_AGENT = "dataset-jgrants (+https://github.com/queria-io/dataset-jgrants)"
OUTPUT = Path("data/jgrants/details.ndjson")
DATASET = "queria/jgrants"
# 8 語で 3,818 件、後ろの 4 語を足して 3,851 件（2026-10-29）。それでも漏れはありうる
KEYWORDS = ["補助", "助成", "支援", "事業", "交付", "奨励", "給付", "補助金", "令和", "年度", "制度", "募集"]
REFRESH_OPEN_AFTER = timedelta(days=7)
# 詳細を続けて取るときの間隔。初回の全件は 1 時間ほどかかる
DETAIL_INTERVAL_SECONDS = 1.0
ATTACHMENTS = ("application_guidelines", "outline_of_grant", "application_form")


def get_json(path: str, params: dict | None = None) -> dict:
    url = f"{API}{path}" + (f"?{urlencode(params)}" if params else "")
    return json.loads(fetch(url, user_agent=USER_AGENT, timeout=120))


def list_subsidies() -> dict[str, dict]:
    def one(keyword: str) -> list[dict]:
        body = get_json(
            "/v1/public/subsidies",
            {"keyword": keyword, "sort": "created_date", "order": "DESC", "acceptance": "0"},
        )
        logger.info("  一覧 %s: %d 件", keyword, len(body["result"]))
        return body["result"]

    return {row["id"]: row for keyword in KEYWORDS for row in one(keyword)}


def parse_time(value: str | None) -> datetime | None:
    try:
        return datetime.fromisoformat(value) if value else None
    except ValueError:
        return None


def is_stale(kept: dict, row: dict, now: datetime) -> bool:
    """受付中で、前回の取得から REFRESH_OPEN_AFTER たったか。"""
    end = parse_time(row.get("acceptance_end_datetime"))
    fetched = parse_time(kept["fetched_at"])
    return bool(end and end >= now and (fetched is None or now - fetched >= REFRESH_OPEN_AFTER))


def fingerprint(row: dict) -> str:
    return hashlib.sha256(json.dumps(row, ensure_ascii=False, sort_keys=True).encode()).hexdigest()


def strip_attachments(detail: dict) -> dict:
    """添付の base64 を捨て、ファイル名だけ残す。"""
    return {
        k: [f.get("name") for f in v or []] if k in ATTACHMENTS else v for k, v in detail.items()
    }


def fetch_detail(subsidy_id: str) -> dict:
    time.sleep(DETAIL_INTERVAL_SECONDS)
    body = get_json(f"/v2/public/subsidies/id/{subsidy_id}")
    return strip_attachments(body.get("result", [body])[0])


def previous_rows() -> dict[str, dict]:
    """前回公開した subsidy.details。初回や読めないときは空。"""
    if os.environ.get("JGRANTS_REFETCH") == "1":
        return {}
    try:
        import queria

        con = queria.connect(user_agent=USER_AGENT)
        con.attach(DATASET, alias="previous")
        rows = con.sql(
            "select id, fingerprint, fetched_at, list_json, detail_json "
            "from previous.subsidy.details"
        ).fetchall()
    except Exception as error:  # noqa: BLE001 初回は存在しないのが正常
        logger.info("  前回の詳細を読めなかったので全件取る: %s", error)
        return {}
    keys = ("id", "fingerprint", "fetched_at", "list_json", "detail_json")
    return {r[0]: dict(zip(keys, r)) for r in rows}


def download_jgrants(output: Path = OUTPUT) -> int:
    listed = list_subsidies()
    logger.info("  一覧の重複を除いて %d 件", len(listed))
    if not listed:
        raise SystemExit("一覧が 0 件（API の形が変わった？）")
    previous = previous_rows()
    started = datetime.now(UTC)
    now = started.isoformat()

    def current(subsidy_id: str, row: dict) -> dict:
        digest = fingerprint(row)
        kept = previous.get(subsidy_id)
        if kept and kept["fingerprint"] == digest and not is_stale(kept, row, started):
            return kept
        return {
            "id": subsidy_id,
            "fingerprint": digest,
            "fetched_at": now,
            "list_json": json.dumps(row, ensure_ascii=False),
            "detail_json": json.dumps(fetch_detail(subsidy_id), ensure_ascii=False),
        }

    rows = {**previous, **{i: current(i, row) for i, row in listed.items()}}
    fetched = sum(r["fetched_at"] == now for r in rows.values())
    logger.info("  詳細を取り直した %d 件、前回のまま %d 件", fetched, len(rows) - fetched)

    output.parent.mkdir(parents=True, exist_ok=True)
    with replacing(output) as partial, partial.open("w", encoding="utf-8") as f:
        f.writelines(json.dumps(r, ensure_ascii=False) + "\n" for r in rows.values())
    return len(rows)
