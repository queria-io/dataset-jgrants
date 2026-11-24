# ビルドと更新

データセットの概要は [README.md](README.md) にあります。ここにはこのリポジトリでデータセットをビルド・更新する手順を書きます。

## ビルド

```bash
git clone https://github.com/queria-io/dataset-shared.git shared  # 更新は git -C shared pull
uv sync
scripts/build.sh                    # fdl checkout → python main.py → fdl commit
JGRANTS_REFETCH=1 scripts/build.sh  # 詳細を全件取得し直す（2 時間ほど）
```

毎日 04:00（日本時間）に Sync が実行されます。
