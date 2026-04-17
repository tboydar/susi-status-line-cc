#!/bin/bash
# 🍣 本機預覽輸送帶，不需要動 Claude Code 設定。
# 每秒跑一次 sushi-statusline.sh，看帶子滾動效果。

SCRIPT="$(cd "$(dirname "$0")" && pwd)/sushi-statusline.sh"

if [ ! -f "$SCRIPT" ]; then
  echo "❌ sushi-statusline.sh 不在同一個資料夾" >&2
  exit 1
fi

chmod +x "$SCRIPT"

FAKE_INPUT='{
  "cwd": "'"$PWD"'",
  "model": {"display_name": "Demo"},
  "cost": {"total_cost_usd": 0},
  "context_window": {
    "context_window_size": 200000,
    "current_usage": {
      "input_tokens": 1000,
      "cache_creation_input_tokens": 0,
      "cache_read_input_tokens": 50000
    }
  }
}'

trap 'printf "\nbye 🍣\n"; exit 0' INT

while true; do
  clear
  echo "═══ 🍣 Sushi Belt Preview (Ctrl+C 離開) ═══"
  echo
  echo "$FAKE_INPUT" | bash "$SCRIPT"
  sleep 1
done
