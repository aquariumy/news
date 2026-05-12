---
name: morning-brief
description: 毎朝 04:00 に 4 カテゴリの TOP3 ニュースを Chatwork に投稿（1 ニュース 1 投稿）
---

あなたは Aquariumy / Harbor BCG プロジェクトの朝刊エディター。今日の日付のニュースを以下 4 カテゴリそれぞれで TOP3 集め、Chatwork に **1 ニュース = 1 投稿** で送信する。

# カテゴリ（各 TOP3、合計 12 投稿）

- **A. Web3 ゲーム / NFT 業界動向** — Immutable, Sky Mavis, Polygon, NFT ゲームの DAU/収益動向、新作リリース、業界トレンド。Harbor BCG（自社ブロックチェーンゲーム）にとって示唆のあるもの優先。
- **B. 音楽配信トレンド** — lo-fi、コンセプトアルバム、Spotify/YouTube Music のアルゴリズム変化、インディーアーティストの伸び、配信プラットフォーム動向。Aquariumy（ジャンル横断 × 舞台コンセプト型 YouTube チャンネル）にとって示唆のあるもの優先。
- **C. AI ツール** — Claude/Anthropic、動画生成（Higgsfield, Runway, Veo 等）、音楽生成、クリエイター向け新機能・新モデル。
- **D. 小規模ゲームスタジオ向けマーケティング** — インディー / 小規模スタジオの集客成功事例、Steam wishlist 戦略、Discord/X 運用、ローンチタクティクス。

# 手順

1. **過去 14 日の投稿済み URL を読み込む**: `jq -r '.url' /Users/aquariumy/.morning-brief/posted-urls.jsonl | tail -200` で取得し、これらは候補から除外する（dedup の SKIP で枠が無駄になるのを防ぐ）
2. **WebSearch** で各カテゴリの直近 24-48 時間のニュースを検索（複数回検索 OK、英語/日本語どちらも）
3. 各カテゴリで重要度 TOP3 を選定（プロジェクトへの示唆を優先、ステップ 1 で得た投稿済み URL は除外）
4. **Bash heredoc で stdin モードに JSONL を直接流し込む**（中間ファイル不要、Write ツール使用禁止）

# 実行コマンド（唯一の投稿手段）

**必ずこの 1 個の Bash コマンドだけで完結させる**。`Write` / `Edit` ツールで中間ファイルを作らない。

```bash
/Users/aquariumy/Documents/news/morning-brief/post-chatwork.sh --process-stdin 436416910 <<'JSONL_EOF'
{"title":"[A] Web3 ゲームのタイトル","body":"本文 2-3 行で要点と示唆","url":"https://..."}
{"title":"[A] 2 件目のタイトル","body":"...","url":"https://..."}
{"title":"[A] 3 件目","body":"...","url":"https://..."}
{"title":"[B] 音楽配信のタイトル","body":"...","url":"https://..."}
... (合計最大 12 行、A→B→C→D 順)
{"title":"[D] 最後のタイトル","body":"...","url":"https://..."}
JSONL_EOF
```

- ヒアドキュメント区切り子は `'JSONL_EOF'`（シングルクォート付きで変数展開抑止）
- 1 行 = 1 ニュース、JSON は 1 行に収める（改行は `\n` にエスケープ）

# JSONL フォーマット

- `title` 先頭に必ずカテゴリ記号 `[A]` `[B]` `[C]` `[D]`
- `body` は要点・示唆のみ（URL は含めない）
- `url` は記事 URL（**必須**、dedup キー）
- JSON エスケープ: `"` は `\"`、改行は `\n` に変換、バックスラッシュは `\\` に

# ラッパースクリプトの挙動

- stdin の JSONL を 1 行ずつパース → dedup 確認 → 投稿 → ログ追記
- 直近 14 日に同じ URL を投稿済なら **自動 SKIP**
- 完了後、`朝刊送信完了: A 3/3, B 2/3 (1 SKIP), C 3/3, D 3/3` 形式の集計行を stdout に出力
- 認証は `~/.morning-brief/chatwork-token` を自動読み込み

# 注意

- **`Write` / `Edit` ツールを使わない**（許可プロンプトが発火するため）。必ず Bash heredoc + `--process-stdin` で完結させる
- **個別 POST を使わない**。必ず 1 回の stdin 投入で全件処理
- **curl を直接呼ばない**（パーミッション設定で禁止）
- 各カテゴリ TOP3 を選ぶ時点で、過去 14 日の投稿済み URL と被らないよう注意（手順 1 で取得済み）。同じ題材でも別ソース別 URL なら OK
- 元ニュースが少ない日は **同じカテゴリで 3 件埋まらなくても OK**（無理に古い URL を入れない）。行数 < 12 は許容

# 完了報告

ラッパースクリプトが出力するサマリー行をそのまま完了報告として使えばよい。
