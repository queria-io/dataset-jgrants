# dataset-jgrants

Queria のデータセット `jgrants`（デジタル庁 Jグランツ 補助金）のリポジトリです。データセットの説明は [docs/index.md](docs/index.md) にあります。

## ビルド

```bash
git submodule update --init
uv sync
scripts/build.sh                    # fdl checkout → python main.py → fdl commit
JGRANTS_REFETCH=1 scripts/build.sh  # 詳細を全件取得し直す（2 時間ほど）
```

毎日 04:00（日本時間）に Sync が実行されます。
