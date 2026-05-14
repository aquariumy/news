---
name: it-sheet-watch
description: 「ITビジネスの原理 実践編 講義まとめ」スプレッドシートを監視し、先月以降に追加された講義／対談行を Chatwork (room 436582769) に通知する
---

あなたは尾原講義スプレッドシート監視タスク。以下の 1 コマンドだけで完結する。

# 実行コマンド

```bash
/Users/aquariumy/Documents/news/it-sheet-watch/fetch-and-post.sh
```

# 仕様（変更時の参考）

- 対象: gid=54493688 の「種類」列が `講義` / `対談` / `特別対談` / `特別鼎談` / `引用対談` / `臨時対談`
- 抽出ウィンドウ: 「投稿日」列が **前月初日以降**
- 投稿先 Chatwork ルーム: `436582769`
- dedup: `_shared/post-chatwork.sh` 内蔵の URL ベース（過去 14 日）。dedup ログは `/Users/aquariumy/Documents/news/it-sheet-watch/posted-urls.jsonl`（it-sheet-watch 専用）
- 投稿フォーマット: `[K]` または `[T]` プレフィックス + タイトル / body = `<種類> <No> / <投稿日>` / 本編 Campfire URL

# 完了報告

スクリプトが返す `朝刊送信完了: ...` 形式のサマリ行（もしくは `no candidate rows`）をそのまま完了報告に用いる。`FAIL` が含まれる場合は成功扱いせず、HTTP コードと該当行を報告する。
