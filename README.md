# news

Aquariumy / Harbor BCG プロジェクトの自動配信ツール群。

- **morning-brief** — 毎朝 04:00 に 4 カテゴリ（Web3 ゲーム / 音楽配信 / AI ツール / 小規模スタジオ向けマーケ）の TOP3 ニュースを集め、Chatwork に 1 ニュース 1 投稿で配信
- **it-sheet-watch** — 毎朝 05:00 に「ITビジネスの原理 実践編 講義まとめ」スプレッドシートを監視し、前月以降に追加された講義／対談行を Chatwork へ通知

## ディレクトリ構成

```
news/
├── _shared/
│   ├── post-chatwork.sh   # 共通 Chatwork 投稿ラッパー（dedup + JSONL/TSV キュー対応）
│   └── chatwork-token     # API トークン（.gitignore 対象、ローカルにのみ存在）
├── morning-brief/
│   ├── SKILL.md           # scheduled-task のプロンプト本体
│   ├── posted-urls.jsonl  # ランタイム dedup ログ（14 日有効）
│   ├── queue.jsonl        # エージェントが各実行で書き出すキュー（毎回上書き）
│   └── icon.png
└── it-sheet-watch/
    ├── SKILL.md           # scheduled-task のプロンプト本体
    ├── fetch-and-post.sh  # gviz CSV 取得 → 抽出 → post-chatwork.sh 呼び出し
    └── posted-urls.jsonl  # ランタイム dedup ログ
```

`SKILL.md` は scheduled-task の固定パスから symlink される（リポジトリ側が正）:

- `~/.claude/scheduled-tasks/morning-brief/SKILL.md`  → `~/Documents/news/morning-brief/SKILL.md`
- `~/.claude/scheduled-tasks/it-sheet-watch/SKILL.md` → `~/Documents/news/it-sheet-watch/SKILL.md`

## セットアップ（新マシン向け）

1. このリポジトリを `~/Documents/news` にクローン
2. Chatwork API トークンを `_shared/chatwork-token` に保存（`.gitignore` 対象）:
   ```bash
   echo -n "<your-token>" > ~/Documents/news/_shared/chatwork-token
   chmod 600 ~/Documents/news/_shared/chatwork-token
   ```
3. scheduled-task の SKILL.md を symlink:
   ```bash
   mkdir -p ~/.claude/scheduled-tasks/morning-brief ~/.claude/scheduled-tasks/it-sheet-watch
   ln -s ~/Documents/news/morning-brief/SKILL.md  ~/.claude/scheduled-tasks/morning-brief/SKILL.md
   ln -s ~/Documents/news/it-sheet-watch/SKILL.md ~/.claude/scheduled-tasks/it-sheet-watch/SKILL.md
   ```
4. `~/.claude/settings.json` の `permissions` に以下を追加:
   ```json
   "additionalDirectories": ["/Users/<you>/Documents/news/"],
   "deny": ["Read(/Users/<you>/Documents/news/_shared/chatwork-token)"],
   "allow": [
     "Bash(/Users/<you>/Documents/news/_shared/post-chatwork.sh:*)",
     "Bash(/Users/<you>/Documents/news/it-sheet-watch/fetch-and-post.sh:*)",
     "WebSearch", "WebFetch"
   ]
   ```
5. Claude Code でスケジュールタスクを 2 件登録（morning-brief: cron `0 4 * * *`, it-sheet-watch: `0 5 * * *`）

## post-chatwork.sh の使い方

呼び出し側は **必ず** `NEWS_POSTED_LOG_FILE` 環境変数でプロジェクト別の dedup ログを指定する（未指定は `exit 5`）。これによりプロジェクト間で dedup ログが混ざることを仕組みで防ぐ。

```bash
NEWS_POSTED_LOG_FILE=~/Documents/news/morning-brief/posted-urls.jsonl \
  ~/Documents/news/_shared/post-chatwork.sh --process-tsv 436416910 <<'NEWS_EOF'
A	タイトル	要点	https://example.com/article
NEWS_EOF
```

トークンは `_shared/chatwork-token`（スクリプト自身のディレクトリから自動解決）または環境変数 `CW_API_TOKEN` で渡す。
