# news

Aquariumy / Harbor BCG プロジェクトの自動朝刊ツール。

毎朝 04:00 に 4 カテゴリ（Web3 ゲーム / 音楽配信 / AI ツール / 小規模スタジオ向けマーケ）の TOP3 ニュースを集め、Chatwork に 1 ニュース 1 投稿で配信する。

## ディレクトリ構成

```
news/
└── morning-brief/
    ├── SKILL.md         # スケジュールタスクのプロンプト本体
    └── post-chatwork.sh # Chatwork 投稿ラッパー（dedup + JSONL キュー対応）
```

両ファイルは下記グローバルパスから symlink される（リポジトリ側が正）:

- `SKILL.md` ← `~/.claude/scheduled-tasks/morning-brief/SKILL.md`
- `post-chatwork.sh` ← `~/.claude/bin/post-chatwork.sh`

## セットアップ（新マシン向け）

1. このリポジトリを `~/Documents/news` にクローン
2. Symlink を貼る:
   ```bash
   ln -s ~/Documents/news/morning-brief/SKILL.md ~/.claude/scheduled-tasks/morning-brief/SKILL.md
   ln -s ~/Documents/news/morning-brief/post-chatwork.sh ~/.claude/bin/post-chatwork.sh
   ```
3. Chatwork API トークンを保存:
   ```bash
   mkdir -p ~/.claude/secrets
   echo -n "<your-token>" > ~/.claude/secrets/chatwork-token
   chmod 600 ~/.claude/secrets/chatwork-token
   ```
4. `~/.claude/settings.json` の `permissions.allow` に以下を追加:
   - `Bash(/Users/<you>/.claude/bin/post-chatwork.sh:*)`
   - `WebSearch`
   - `Write(/Users/<you>/.claude/data/morning-brief/queue.jsonl)`
5. Claude Code でスケジュールタスクを登録（cron `0 4 * * *`）し、`SKILL.md` の内容を prompt として設定

## ランタイムデータ（Git 管理外）

- `~/.claude/data/morning-brief/posted-urls.jsonl` — dedup ログ（14 日有効）
- `~/.claude/data/morning-brief/queue.jsonl` — エージェントが各実行で書き出すキュー（毎回上書き）
- `~/.claude/secrets/chatwork-token` — API トークン
