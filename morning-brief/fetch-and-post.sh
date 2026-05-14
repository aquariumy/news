#!/usr/bin/env bash
# Read queue.tsv (prepared by Claude via the Write tool) and forward it to
# post-chatwork.sh for dedup-aware Chatwork posting (room 436416910).
# Truncate queue.tsv after a successful submission.
#
# Usage:
#   fetch-and-post.sh           # post to Chatwork
#   fetch-and-post.sh --dry-run # print TSV that would be sent, do not post

set -u

ROOM_ID="436416910"
POSTER="/Users/aquariumy/Documents/news/_shared/post-chatwork.sh"
POSTED_LOG="/Users/aquariumy/Documents/news/morning-brief/posted-urls.jsonl"
QUEUE="/Users/aquariumy/Documents/news/morning-brief/queue.tsv"

DRY_RUN=0
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=1
fi

if [ ! -f "$QUEUE" ]; then
  echo "error: queue file not found: $QUEUE" >&2
  exit 1
fi

if [ ! -s "$QUEUE" ]; then
  echo "no candidate rows (queue.tsv is empty)"
  exit 0
fi

count=$(grep -c '.' "$QUEUE" 2>/dev/null || echo 0)
echo "candidates: $count rows"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "--- TSV (dry-run, would be sent to room ${ROOM_ID}) ---"
  cat "$QUEUE"
  exit 0
fi

if [ ! -x "$POSTER" ]; then
  echo "error: poster not executable: $POSTER" >&2
  exit 1
fi

NEWS_POSTED_LOG_FILE="$POSTED_LOG" "$POSTER" --process-tsv "$ROOM_ID" < "$QUEUE"
rc=$?

if [ "$rc" -eq 0 ]; then
  : > "$QUEUE"
fi

exit "$rc"
