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
# 一次 jq 讀完所有欄位
# 一欄一行、逐行讀進陣列：空值也會佔一行，不會被吃掉
# （bash 的 read 以空白為 IFS，會把連續 tab 併成一個，故不用 tab 分隔）
# ═══════════════════════════════════════════
F=()
while IFS= read -r line; do
  F+=("$line")
done < <(echo "$input" | jq -r '
  .cwd // .workspace.current_dir // "",
  .model.display_name // "N/A",
  .cost.total_cost_usd // 0,
  .context_window.context_window_size // 0,
  .context_window.current_usage.input_tokens // 0,
  .context_window.current_usage.cache_creation_input_tokens // 0,
  .context_window.current_usage.cache_read_input_tokens // 0,
  .rate_limits.five_hour.used_percentage // "",
  .rate_limits.seven_day.used_percentage // "",
  .rate_limits.five_hour.resets_at // ""
')
CURRENT_DIR="${F[0]}"; MODEL="${F[1]}"; COST="${F[2]}"
CTX_SIZE="${F[3]}"; CTX_IN="${F[4]}"; CTX_CC="${F[5]}"; CTX_CR="${F[6]}"
RATE_5H="${F[7]}"; RATE_7D="${F[8]}"; RATE_5H_RESET="${F[9]}"

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
[ -z "$CURRENT_DIR" ] && CURRENT_DIR=$(pwd)
FOLDER_NAME=$(basename "$CURRENT_DIR")

# git -C 而非 cd：不改動本行程的工作目錄
GIT_INFO=""
if [ -d "$CURRENT_DIR" ] && git -C "$CURRENT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  BRANCH=$(git -C "$CURRENT_DIR" branch --show-current 2>/dev/null)
  [ -z "$BRANCH" ] && BRANCH=$(git -C "$CURRENT_DIR" rev-parse --short HEAD 2>/dev/null)
  STAGED=$(git -C "$CURRENT_DIR" diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
  UNSTAGED=$(git -C "$CURRENT_DIR" diff --numstat 2>/dev/null | wc -l | tr -d ' ')
  UNTRACKED=$(git -C "$CURRENT_DIR" ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
  TOTAL=$((STAGED + UNSTAGED + UNTRACKED))
  if [ "$TOTAL" -gt 0 ]; then
    GIT_INFO="🌿 $BRANCH (+$TOTAL)"
  else
    GIT_INFO="🌿 $BRANCH"
  fi
fi

COST_FMT=$(printf "%.4f" "$COST")
CTX_USED=$((CTX_IN + CTX_CC + CTX_CR))
if [ "$CTX_SIZE" -gt 0 ] 2>/dev/null; then
  CTX_PCT=$(awk "BEGIN {printf \"%.0f\", ($CTX_USED/$CTX_SIZE)*100}")
else
  CTX_PCT="0"
fi

# unix epoch → HH:MM。BSD date 吃 -r，GNU date 吃 -d @；兩個都試才能跨平台
fmt_hhmm() { date -r "$1" +"%H:%M" 2>/dev/null || date -d "@$1" +"%H:%M" 2>/dev/null; }

RATE_INFO=""
if [ -n "$RATE_5H" ]; then
  RATE_5H_INT=$(printf "%.0f" "$RATE_5H")
  if [ "$RATE_5H_INT" -ge 80 ]; then RATE_ICON="🔴"
  elif [ "$RATE_5H_INT" -ge 50 ]; then RATE_ICON="🟡"
  else RATE_ICON="🟢"; fi
  RATE_INFO="${RATE_ICON} 5h:${RATE_5H_INT}%"
  if [ -n "$RATE_7D" ]; then
    RATE_7D_INT=$(printf "%.0f" "$RATE_7D")
    RATE_INFO="${RATE_INFO} 7d:${RATE_7D_INT}%"
  fi
  if [ -n "$RATE_5H_RESET" ]; then
    RESET_TIME=$(fmt_hhmm "$RATE_5H_RESET")
    [ -n "$RESET_TIME" ] && RATE_INFO="${RATE_INFO} ↻${RESET_TIME}"
  fi
fi

TIME_NOW=$(date +"%H:%M:%S")

LINE2="📁 ${FOLDER_NAME}"
[ -n "$GIT_INFO" ] && LINE2="$LINE2 | $GIT_INFO"
LINE2="$LINE2 | 🥢 $MODEL | 💰\$$COST_FMT | 📐${CTX_PCT}%"
[ -n "$RATE_INFO" ] && LINE2="$LINE2 | $RATE_INFO"
LINE2="$LINE2 | 🕐$TIME_NOW"

echo "$BELT"
echo "$LINE2"
