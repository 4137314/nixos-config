#!/usr/bin/env bash
# Cached host-health segment used by the tmux status line.

set -uo pipefail

cache_dir="${XDG_RUNTIME_DIR:-/tmp}"
if [ ! -w "$cache_dir" ]; then
  cache_dir=/tmp
fi
cache_file="$cache_dir/hb-tmux-health-${UID}"
now=$(date +%s)
mtime=$(stat --format=%Y "$cache_file" 2>/dev/null || printf '0')

if [ -r "$cache_file" ] && [ $((now - mtime)) -lt 5 ]; then
  cat "$cache_file"
  exit 0
fi

failed_system=$(systemctl --failed --no-legend --plain 2>/dev/null \
  | awk 'NF { count++ } END { print count + 0 }')
failed_user=$(systemctl --user --failed --no-legend --plain 2>/dev/null \
  | awk 'NF { count++ } END { print count + 0 }')
failed=$((failed_system + failed_user))

payload=$(curl --fail --silent --max-time 1 --get \
  http://127.0.0.1:9090/api/v1/query \
  --data-urlencode 'query=ALERTS{alertstate=~"firing|pending"}' 2>/dev/null || true)
if jq -e '.status == "success"' >/dev/null 2>&1 <<<"$payload"; then
  alerts=$(jq -r '.data.result | length' <<<"$payload")
else
  alerts="?"
fi

root_use=$(df --output=pcent / 2>/dev/null | tail -n 1 | tr -d ' ')
tmp_file="$cache_file.tmp.$$"

if [ "$failed" -gt 0 ]; then
  printf '#[fg=#ff3355,bold]FAIL %s#[fg=#768096] · ' "$failed" >"$tmp_file"
else
  printf '#[fg=#00ff88,bold]OK#[fg=#768096] · ' >"$tmp_file"
fi

if [ "$alerts" = "0" ]; then
  printf '#[fg=#00ff88]ALERT 0#[fg=#768096] · ' >>"$tmp_file"
elif [ "$alerts" = "?" ]; then
  printf '#[fg=#ffb000]ALERT ?#[fg=#768096] · ' >>"$tmp_file"
else
  printf '#[fg=#ff3355,bold]ALERT %s#[fg=#768096] · ' "$alerts" >>"$tmp_file"
fi

printf '#[fg=#d7e2ff]ROOT %s' "${root_use:-?}" >>"$tmp_file"
mv "$tmp_file" "$cache_file"
cat "$cache_file"
