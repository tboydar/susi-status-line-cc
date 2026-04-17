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

trap 'printf "\n\nbye 🍣\n"; exit 0' INT

printf "═══ 🍣 Sushi Belt Preview (Ctrl+C 離開) ═══\n\n"

first=1
while true; do
  if [ -z "$first" ]; then
    printf "\033[2A\033[J"   # 上移 2 行並清除到螢幕底，原地更新不閃爍
  fi
  first=
  echo "$FAKE_INPUT" | bash "$SCRIPT"
  sleep 1
done
