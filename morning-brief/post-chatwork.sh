#!/usr/bin/env bash
# Post message(s) to Chatwork. Two modes:
#
#   Single post (3-4 args):
#     post-chatwork.sh <room_id> <title> <body> [<url>]
#
#   Queue mode (recommended for scheduled tasks; avoids shell-metachar issues):
#     post-chatwork.sh --process-queue <jsonl_file> <room_id>
#     Each JSONL line: {"title":"...","body":"...","url":"..."}
#     The URL is required when dedup is desired (otherwise post will not dedup).
#
# Dedup: a posted URL is skipped if the same URL appears in
#        ~/.claude/data/morning-brief/posted-urls.jsonl within the last 14 days.
#
# Token: read from $CW_API_TOKEN, then ~/.claude/secrets/chatwork-token.

set -u

API_BASE="https://api.chatwork.com/v2"
LOG_FILE="$HOME/.claude/data/morning-brief/posted-urls.jsonl"

load_token() {
  if [ -z "${CW_API_TOKEN:-}" ]; then
    local token_file="$HOME/.claude/secrets/chatwork-token"
    if [ -r "$token_file" ]; then
      CW_API_TOKEN=$(cat "$token_file")
    fi
  fi
  if [ -z "${CW_API_TOKEN:-}" ]; then
    echo "error: CW_API_TOKEN is not set and $HOME/.claude/secrets/chatwork-token is missing" >&2
    exit 3
  fi
}

ensure_log() {
  mkdir -p "$(dirname "$LOG_FILE")"
  touch "$LOG_FILE"
}

# Returns 0 if URL was posted within the last 14 days (i.e., should skip).
should_skip() {
  local url="$1"
  [ -z "$url" ] && return 1
  local cutoff_epoch
  cutoff_epoch=$(date -v-14d +%s 2>/dev/null || date -d "14 days ago" +%s)
  local matching_date
  matching_date=$(grep -F "\"url\":\"$url\"" "$LOG_FILE" 2>/dev/null \
    | sed -n 's/.*"date":"\([^"]*\)".*/\1/p' | sort -r | head -1)
  [ -z "$matching_date" ] && return 1
  local matching_epoch
  matching_epoch=$(date -j -f "%Y-%m-%d" "$matching_date" +%s 2>/dev/null \
    || date -d "$matching_date" +%s 2>/dev/null || echo 0)
  [ "$matching_epoch" -ge "$cutoff_epoch" ]
}

# Post a single message. Args: room_id, title, body, url (may be empty).
# Returns: 0 on success, 1 on HTTP failure, 2 on skip.
post_one() {
  local room_id="$1" title="$2" body="$3" url="$4"

  if should_skip "$url"; then
    echo "SKIP $title"
    return 2
  fi

  local payload
  if [ -n "$url" ]; then
    payload="[info][title]${title}[/title]
${body}
${url}
[/info]"
  else
    payload="[info][title]${title}[/title]
${body}
[/info]"
  fi

  local http_code
  http_code=$(curl -s -o /tmp/chatwork-response.json -w "%{http_code}" \
    -X POST "${API_BASE}/rooms/${room_id}/messages" \
    -H "X-ChatWorkToken: ${CW_API_TOKEN}" \
    --data-urlencode "body=${payload}")

  if [ "$http_code" = "200" ]; then
    echo "OK $title"
    if [ -n "$url" ]; then
      local today safe_title safe_url
      today=$(date +%Y-%m-%d)
      safe_title=${title//\"/\\\"}
      safe_url=${url//\"/\\\"}
      printf '{"date":"%s","url":"%s","title":"%s"}\n' "$today" "$safe_url" "$safe_title" >> "$LOG_FILE"
    fi
    return 0
  else
    echo "FAIL $http_code $title" >&2
    cat /tmp/chatwork-response.json >&2
    echo >&2
    return 1
  fi
}

# Process a JSONL queue file. Args: queue_file, room_id.
process_queue() {
  local queue_file="$1" room_id="$2"
  if [ ! -r "$queue_file" ]; then
    echo "error: queue file not readable: $queue_file" >&2
    exit 4
  fi

  # Per-category counters (bash 3 compatible — no assoc arrays).
  local A_ok=0 A_skip=0 A_fail=0
  local B_ok=0 B_skip=0 B_fail=0
  local C_ok=0 C_skip=0 C_fail=0
  local D_ok=0 D_skip=0 D_fail=0
  local X_ok=0 X_skip=0 X_fail=0  # uncategorized

  local line title body url cat rc
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    title=$(jq -r '.title // ""' <<<"$line")
    body=$(jq -r '.body // ""' <<<"$line")
    url=$(jq -r '.url // ""' <<<"$line")
    if [ -z "$title" ] || [ -z "$body" ]; then
      echo "WARN skipping malformed line: $line" >&2
      continue
    fi
    cat=$(printf '%s' "$title" | sed -n 's/^\[\([A-Z]\)\].*/\1/p')
    [ -z "$cat" ] && cat="X"

    post_one "$room_id" "$title" "$body" "$url"
    rc=$?
    case "$rc:$cat" in
      0:A) A_ok=$((A_ok+1)) ;; 2:A) A_skip=$((A_skip+1)) ;; *:A) A_fail=$((A_fail+1)) ;;
      0:B) B_ok=$((B_ok+1)) ;; 2:B) B_skip=$((B_skip+1)) ;; *:B) B_fail=$((B_fail+1)) ;;
      0:C) C_ok=$((C_ok+1)) ;; 2:C) C_skip=$((C_skip+1)) ;; *:C) C_fail=$((C_fail+1)) ;;
      0:D) D_ok=$((D_ok+1)) ;; 2:D) D_skip=$((D_skip+1)) ;; *:D) D_fail=$((D_fail+1)) ;;
      0:X) X_ok=$((X_ok+1)) ;; 2:X) X_skip=$((X_skip+1)) ;; *:X) X_fail=$((X_fail+1)) ;;
    esac
  done < "$queue_file"

  local summary="朝刊送信完了:"
  local c ok sk fa total part
  for c in A B C D X; do
    eval "ok=\$${c}_ok"
    eval "sk=\$${c}_skip"
    eval "fa=\$${c}_fail"
    total=$((ok + sk + fa))
    if [ "$c" = "X" ] && [ "$total" -eq 0 ]; then
      continue
    fi
    part=" $c $ok/$total"
    [ "$sk" -gt 0 ] && part="$part ($sk SKIP)"
    [ "$fa" -gt 0 ] && part="$part ($fa FAIL)"
    summary="$summary$part,"
  done
  echo "${summary%,}"
}

# --- main ---
load_token
ensure_log

if [ "${1:-}" = "--process-queue" ]; then
  if [ "$#" -ne 3 ]; then
    echo "usage: $(basename "$0") --process-queue <jsonl_file> <room_id>" >&2
    exit 2
  fi
  process_queue "$2" "$3"
  exit 0
fi

if [ "$#" -lt 3 ] || [ "$#" -gt 4 ]; then
  echo "usage: $(basename "$0") <room_id> <title> <body> [<url>]" >&2
  echo "       $(basename "$0") --process-queue <jsonl_file> <room_id>" >&2
  exit 2
fi

post_one "$1" "$2" "$3" "${4:-}"
exit $?
