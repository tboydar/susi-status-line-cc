#!/bin/bash
# 🍣 Sushi Conveyor Belt Status Line for Claude Code
# 每秒 L→R 滾動的迴轉壽司 status line。
# Docs: see README.md in the same folder.

input=$(cat)

# ═══════════════════════════════════════════
# Tunables
# ═══════════════════════════════════════════
SLOTS_VISIBLE=30      # 帶子長度（slot 數）
EMPTY_PROB=65         # % 空格機率（越高越稀疏）

# 🍣 壽司 emoji 池，自行替換口味
SUSHI=("🍣" "🍱" "🍤" "🍙" "🍥" "🐙" "🍵" "🦐" "🥟" "🦑" "🍶" "🍘")
NUM_SUSHI=${#SUSHI[@]}

# ═══════════════════════════════════════════
# 建構輸送帶
# 核心：slot 內容 = f(position - NOW)
#   NOW 每秒 +1，同一內容會出現在右邊一格 → L→R，無需保存 state
# ═══════════════════════════════════════════
NOW=$(date +%s)

# bash 的 % 保留被除數正負號；我們要純正數 mod
pos_mod() { echo $(( (($1 % $2) + $2) % $2 )); }

BELT="▸"
for ((p=0; p<SLOTS_VISIBLE; p++)); do
  slot_id=$(( p - NOW ))
  # hash1：這個 slot 是空格還是壽司？
  h1=$(pos_mod $(( slot_id * 2654435761 + 1013904223 )) 100)
  if [ "$h1" -lt "$EMPTY_PROB" ]; then
    BELT="${BELT}═══"
  else
    # hash2：用獨立常數另外挑壽司，避免和 h1 相關
    h2=$(pos_mod $(( slot_id * 374761393 + 668265263 )) "$NUM_SUSHI")
    BELT="${BELT}${SUSHI[$h2]}"
  fi
done
BELT="${BELT}▸"

# ═══════════════════════════════════════════
# 資訊列：資料夾、git、model、cost、context、rate、時間
# ═══════════════════════════════════════════
CURRENT_DIR=$(echo "$input" | jq -r '.cwd // .workspace.current_dir // ""')
[ -z "$CURRENT_DIR" ] && CURRENT_DIR=$(pwd)
FOLDER_NAME=$(basename "$CURRENT_DIR")

GIT_INFO=""
if [ -d "$CURRENT_DIR" ] && cd "$CURRENT_DIR" 2>/dev/null; then
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    BRANCH=$(git branch --show-current 2>/dev/null)
    [ -z "$BRANCH" ] && BRANCH=$(git rev-parse --short HEAD 2>/dev/null)
    STAGED=$(git diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
    UNSTAGED=$(git diff --numstat 2>/dev/null | wc -l | tr -d ' ')
    UNTRACKED=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
    TOTAL=$((STAGED + UNSTAGED + UNTRACKED))
    if [ "$TOTAL" -gt 0 ]; then
      GIT_INFO="🌿 $BRANCH (+$TOTAL)"
    else
      GIT_INFO="🌿 $BRANCH"
    fi
  fi
fi

MODEL=$(echo "$input" | jq -r '.model.display_name // "N/A"')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
COST_FMT=$(printf "%.4f" "$COST")
CTX_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
CTX_IN=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // 0')
CTX_CC=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')
CTX_CR=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')
CTX_USED=$((CTX_IN + CTX_CC + CTX_CR))
if [ "$CTX_SIZE" -gt 0 ] 2>/dev/null; then
  CTX_PCT=$(awk "BEGIN {printf \"%.0f\", ($CTX_USED/$CTX_SIZE)*100}")
else
  CTX_PCT="0"
fi

RATE_5H=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
RATE_INFO=""
if [ -n "$RATE_5H" ]; then
  RATE_5H_INT=$(printf "%.0f" "$RATE_5H")
  if [ "$RATE_5H_INT" -ge 80 ]; then RATE_ICON="🔴"
  elif [ "$RATE_5H_INT" -ge 50 ]; then RATE_ICON="🟡"
  else RATE_ICON="🟢"; fi
  RATE_INFO="${RATE_ICON} 5h:${RATE_5H_INT}%"
fi

TIME_NOW=$(date +"%H:%M:%S")

LINE2="📁 ${FOLDER_NAME}"
[ -n "$GIT_INFO" ] && LINE2="$LINE2 | $GIT_INFO"
LINE2="$LINE2 | 🥢 $MODEL | 💰\$$COST_FMT | 📐${CTX_PCT}%"
[ -n "$RATE_INFO" ] && LINE2="$LINE2 | $RATE_INFO"
LINE2="$LINE2 | 🕐$TIME_NOW"

echo "$BELT"
echo "$LINE2"
