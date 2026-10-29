"""J グランツ（デジタル庁）データパイプライン。

1. jgrants: 公開 API から補助金の一覧と詳細を取り出す
2. dbt: dbt ビルド
"""

import logging

from dbt.cli.main import dbtRunner

from pipelines.jgrants import download_jgrants

logging.basicConfig(level=logging.INFO, format="%(message)s")
logger = logging.getLogger("pipelines")


def dbt_build():
    dbt = dbtRunner()
    for command in (["deps"], ["build"], ["docs", "generate"]):
        result = dbt.invoke(command)
        if not result.success:
            raise SystemExit(f"dbt {' '.join(command)} failed")


def main():
    logger.info("1/2: jgrants (補助金の一覧と詳細)")
    download_jgrants()

    logger.info("2/2: dbt build")
    dbt_build()


if __name__ == "__main__":
    main()
