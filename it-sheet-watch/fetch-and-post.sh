#!/usr/bin/env bash
# Fetch the "ITビジネスの原理 実践編 講義まとめ" sheet (gid=54493688),
# extract rows whose 投稿日 is on/after the first day of the previous month
# in the target 種類 categories (講義 / 対談 / 特別対談 / 特別鼎談 / 引用対談 / 臨時対談),
# then forward them as TSV to post-chatwork.sh for dedup-aware Chatwork posting.
#
# Usage:
#   fetch-and-post.sh           # post to Chatwork (room 436582769)
#   fetch-and-post.sh --dry-run # print TSV that would be sent, do not post
#
# Dedup is delegated to post-chatwork.sh (URL-based, 14-day window via
# ~/.morning-brief/posted-urls.jsonl).

set -u

SHEET_ID="1BHkAdIsrhcHzS8c8f6ys1AFGhVhgLk9s03clyQea2nk"
GID="54493688"
ROOM_ID="436582769"
POSTER="/Users/aquariumy/Documents/news/_shared/post-chatwork.sh"
POSTED_LOG="/Users/aquariumy/Documents/news/it-sheet-watch/posted-urls.jsonl"

DRY_RUN=0
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=1
fi

tmp_csv=$(mktemp -t it-sheet-watch.XXXXXX.csv)
trap 'rm -f "$tmp_csv"' EXIT

http_code=$(curl -sL -o "$tmp_csv" -w "%{http_code}" \
  "https://docs.google.com/spreadsheets/d/${SHEET_ID}/gviz/tq?tqx=out:csv&gid=${GID}")

if [ "$http_code" != "200" ]; then
  echo "error: gviz fetch failed (HTTP $http_code)" >&2
  exit 1
fi
if [ ! -s "$tmp_csv" ]; then
  echo "error: empty CSV" >&2
  exit 1
fi

# Compute the first day of the previous month in YY/MM/01 form.
prev_month=$(date -v-1m +%y/%m/01 2>/dev/null || date -d "last month" +%y/%m/01)

tsv=$(SHEET_CSV="$tmp_csv" PREV_MONTH="$prev_month" python3 - <<'PY'
import csv, os, sys
from datetime import datetime

path = os.environ["SHEET_CSV"]
prev = os.environ["PREV_MONTH"]
pm_dt = datetime.strptime("20" + prev, "%Y/%m/%d")

target = {"講義", "対談", "特別対談", "特別鼎談", "引用対談", "臨時対談"}

out = []
with open(path, encoding="utf-8", newline="") as f:
    reader = csv.reader(f)
    for row in reader:
        if len(row) < 5:
            continue
        kind, no, date, title, url = row[0], row[1], row[2], row[3], row[4]
        if kind not in target:
            continue
        if not date or not url or not title:
            continue
        try:
            d = datetime.strptime("20" + date, "%Y/%m/%d")
        except ValueError:
            continue
        if d < pm_dt:
            continue
        cat = "K" if kind == "講義" else "T"
        body = f"{kind} {no} / {date}"
        title_s = title.replace("\t", " ").replace("\n", " ").replace("\r", " ")
        body_s = body.replace("\t", " ").replace("\n", " ").replace("\r", " ")
        url_s = url.strip().replace("\t", " ").replace("\n", " ").replace("\r", " ")
        out.append(f"{cat}\t{title_s}\t{body_s}\t{url_s}")

sys.stdout.write("\n".join(out))
if out:
    sys.stdout.write("\n")
PY
)

py_rc=$?
if [ "$py_rc" -ne 0 ]; then
  echo "error: python parse failed (rc=$py_rc)" >&2
  exit 1
fi

if [ -z "$tsv" ]; then
  echo "no candidate rows (window: ${prev_month} onward)"
  exit 0
fi

count=$(printf '%s\n' "$tsv" | grep -c '.')
echo "candidates: $count rows (window: ${prev_month} onward)"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "--- TSV (dry-run, would be sent to room ${ROOM_ID}) ---"
  printf '%s\n' "$tsv"
  exit 0
fi

if [ ! -x "$POSTER" ]; then
  echo "error: poster not executable: $POSTER" >&2
  exit 1
fi

printf '%s\n' "$tsv" | NEWS_POSTED_LOG_FILE="$POSTED_LOG" "$POSTER" --process-tsv "$ROOM_ID"
