#!/bin/bash
# 🍣 一鍵準備：chmod + 印出要貼進 settings.json 的 JSON 片段
# 不會自動改你的 settings.json，貼上動作留給你自己。

set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/sushi-statusline.sh"
DEMO="$HERE/demo.sh"

if [ ! -f "$SCRIPT" ]; then
  echo "❌ 找不到 sushi-statusline.sh，確認你在正確的資料夾執行" >&2
  exit 1
fi

chmod +x "$SCRIPT" "$DEMO" 2>/dev/null

cat <<EOF

🍣 準備完成！

請把以下片段加入 ~/.claude/settings.json 的最上層（若已有其他欄位，只要合併 "statusLine" key）：

  "statusLine": {
    "type": "command",
    "command": "$SCRIPT",
    "refreshInterval": 1
  }

步驟：
  1. 打開 ~/.claude/settings.json
  2. 貼入上面片段（注意跟現有內容間的逗號）
  3. 存檔
  4. 重啟 Claude Code session

想先看效果？
  $DEMO

EOF
