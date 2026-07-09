# 🍣 Sushi Status Line for Claude Code

![Sushi belt demo](assets/demo.gif)

Claude Code 的 status line 變成一條迴轉壽司輸送帶：每秒 🍣🍱🍤 從左往右流過，中間隨機空隙，idle 時也會動。

## 預覽

連續 5 秒的輸送帶（注意 🥟 從左邊緩緩滑到右邊）：

```
▸══════🥟════════════🍱══════🍥═══🍵══════🦑═══🍘══════🍤════════════🦐══════🍶═══▸
▸🐙══════🥟════════════🍱══════🍥═══🍵══════🦑═══🍘══════🍤════════════🦐══════🍶▸
▸═══🐙══════🥟════════════🍱══════🍥═══🍵══════🦑═══🍘══════🍤════════════🦐══════▸
▸🍙═══🐙══════🥟════════════🍱══════🍥═══🍵══════🦑═══🍘══════🍤════════════🦐═══▸
▸═══🍙═══🐙══════🥟════════════🍱══════🍥═══🍵══════🦑═══🍘══════🍤════════════🦐▸
```

下方資訊列：

```
📁 my-project | 🌿 main | 🥢 Opus 4.7 | 💰$0.1234 | 📐26% | 🕐09:49:31
```

Claude Code 有回傳 `rate_limits` 時，會多一段用量（5 小時、7 天、5 小時額度重設時間）：

```
📁 my-project | 🌿 main (+3) | 🥢 Opus 4.7 | 💰$0.1234 | 📐26% | 🟢 5h:12% 7d:34% ↻14:30 | 🕐09:49:31
```

> 想看動畫版？見本 repo `assets/demo.tape`，用 [vhs](https://github.com/charmbracelet/vhs) 可以自動產生 GIF。

---

## 相容性

| 平台 | 狀態 |
|---|---|
| macOS | ✅ 實測可用 |
| Linux | 🤔 語法上 POSIX 相容，**尚未實測**，歡迎回報 |
| Windows（WSL / Git Bash） | 🤔 理論可行，尚未實測 |
| Windows（原生 PowerShell） | ❌ 不支援（腳本是 bash） |

主腳本只用 `bash` + `jq` + `date` + `awk` + `printf`，並避開 `stat -f`、`sed -i ""` 這類 BSD-only 指令，所以 Linux 理論上能直接跑。實測後歡迎開 issue 回報結果。

唯一的平台分歧是把 rate limit 的 `resets_at`（unix epoch）格式化成 `HH:MM`：BSD 用 `date -r <epoch>`，GNU coreutils 的 `date -r` 卻是讀「檔案 mtime」、要改用 `date -d @<epoch>`。腳本兩種都試：

```bash
fmt_hhmm() { date -r "$1" +"%H:%M" 2>/dev/null || date -d "@$1" +"%H:%M" 2>/dev/null; }
```

兩者都失敗時就不顯示 `↻`，其餘欄位照常。

---

## 從零開始安裝

### 1. 先有 Claude Code

這個 status line 只適用於 [Claude Code](https://claude.com/product/claude-code)（Anthropic 官方 CLI）。還沒有的話：

```bash
# macOS / Linux
curl -fsSL https://claude.com/claude-code/install.sh | bash
```

裝好後執行 `claude` 開第一個 session，確認能跑就 `exit` 離開。

> 需要 **Claude Code 2.x 以上**（`refreshInterval` 在 2.x 才加進去）。

### 2. 確認相依工具

```bash
command -v bash && bash --version | head -1   # 需要 bash 3+
command -v jq   && jq --version               # 處理 status line 的 JSON 輸入
```

- macOS：`jq` 若沒裝 → `brew install jq`
- Ubuntu / Debian：`sudo apt install jq`

### 3. 取得本 repo

```bash
# 放到任一位置，例如 ~/.claude/hud/sushi
git clone https://github.com/tboydar/susi-status-line-cc.git ~/.claude/hud/sushi
cd ~/.claude/hud/sushi
```

### 4. 預覽（選擇性，但推薦）

先看看是不是你喜歡的樣子，再決定要不要掛上 Claude Code：

```bash
./demo.sh
```

終端機會每秒更新一次壽司帶，按 `Ctrl+C` 離開。

### 5. 掛到 Claude Code

```bash
./install.sh
```

會印出要貼進 `~/.claude/settings.json` 的 JSON 片段，長這樣：

```json
"statusLine": {
  "type": "command",
  "command": "/your/clone/path/sushi-statusline.sh",
  "refreshInterval": 1
}
```

**貼進 settings.json 的步驟：**

1. 打開 `~/.claude/settings.json`（沒有就新建一個 `{}` 空物件）
2. 把上面的 `"statusLine": { ... }` 合併到最上層
3. 檢查整份 JSON 仍合法：`jq . ~/.claude/settings.json`

完整的 `settings.json` 長這樣（最小範例）：

```json
{
  "statusLine": {
    "type": "command",
    "command": "/Users/you/.claude/hud/sushi/sushi-statusline.sh",
    "refreshInterval": 1
  }
}
```

### 6. 重啟 Claude Code

關掉現有 session（`exit`）然後重新 `claude`，壽司帶就會出現在底部。

---

## 自訂參數

編輯 `sushi-statusline.sh` 頂端：

| 變數 | 預設 | 說明 |
|---|---|---|
| `SLOTS_VISIBLE` | `30` | 帶子總長（slot 數）。越大越長 |
| `EMPTY_PROB` | `65` | 空格機率（%）。30 很密、80 很稀疏 |
| `SUSHI=(...)` | 12 種 | 壽司 emoji 池。想換口味直接改 |

改完執行 `./demo.sh` 即時看效果。

---

## 運作原理

### L→R 滾動的數學

關鍵：**每個 slot 的內容只取決於 `slot_id = position - NOW`**。

```
C(p, t)     = g(p - t)
C(p+1, t+1) = g((p+1) - (t+1)) = g(p - t) = C(p, t)  ✓
```

時間推進 1 秒，同一個內容會出現在**右邊一格**——這就是 L→R。不需要保存 state，每次渲染都是 pure function。

### 兩把獨立 hash

為了讓「空/有」與「哪盤壽司」兩個決策互不相關，用兩個不同大質數對同一個 `slot_id` 做 hash：

```bash
h1 = hash1(slot_id) % 100      # 是否空格（與 EMPTY_PROB 比較）
h2 = hash2(slot_id) % NUM_SUSHI # 哪種壽司
```

同一個 `slot_id` 永遠映射到同一盤壽司，所以壽司從螢幕右側退場、下一生命週期從左邊重新進場時**還是那盤**——視覺上連續。

### bash 正數 mod 的坑

bash 的 `%` 保留被除數正負號：

```bash
$ echo $(( -5 % 100 ))
-5          # 不是 95
```

`slot_id = p - NOW` 必為大負數，所以包了 `pos_mod`：

```bash
pos_mod() { echo $(( (($1 % $2) + $2) % $2 )); }
```

### `refreshInterval: 1` 讓它真的動

Claude Code 的 status line 預設**只在事件觸發時重繪**（你打字、工具回來等），idle 時會卡住。2.x 的 `settings.json` 支援 `refreshInterval`，單位秒，最小值 1：

```json
"statusLine": { ..., "refreshInterval": 1 }
```

官方文件：<https://code.claude.com/docs/en/statusline.md>

---

## 延伸玩法

### 壽司旁邊加筆記標題

這版刻意把文字拿掉（留白比資訊量重要），但基礎邏輯通用。找到這段：

```bash
h2=$(pos_mod $(( slot_id * 374761393 + 668265263 )) "$NUM_SUSHI")
BELT="${BELT}${SUSHI[$h2]}"
```

改成從你自己的文字池（例如 `~/notes/*.md` 的標題）抽一則：

```bash
h2=$(pos_mod $(( slot_id * 374761393 + 668265263 )) "$NUM_SUSHI")
h3=$(pos_mod $(( slot_id * 40503 + 2246822519 )) "$NUM_ITEMS")
BELT="${BELT}${SUSHI[$h2]}${ITEMS[$h3]} "
```

記得用快取檔存掃描結果，不要每次渲染都 I/O。

### 換成拉麵、啤酒、行星……

改 `SUSHI=(...)` 陣列即可。邏輯是通用的輸送帶，換 emoji 就變主題。

### 產生動畫 GIF

安裝 [vhs](https://github.com/charmbracelet/vhs)：

```bash
brew install vhs           # macOS
# 或從 GitHub release 下載
```

然後：

```bash
vhs assets/demo.tape
# → 產出 assets/demo.gif
```

---

## 疑難排解

| 症狀 | 原因 | 解法 |
|---|---|---|
| 帶子完全不動 | `settings.json` 沒加 `refreshInterval: 1` | 編輯補上 |
| 某些 slot 顯示 `�` 或方框 | 終端字型不支援部分 emoji | 換等寬 emoji 字型（Fira Code + emoji fallback、Hack Nerd Font 等） |
| 帶子太擠或太空 | `EMPTY_PROB` 不合胃口 | 改 tunables、`./demo.sh` 試 |
| 整條顯示到第二行 | 終端太窄 | 縮小 `SLOTS_VISIBLE` |
| 資訊列缺 rate limit | Claude Code 未回傳 `rate_limits` 欄位 | 正常，只在特定訂閱方案下出現 |
| `install.sh: permission denied` | 沒執行權限 | `chmod +x install.sh demo.sh sushi-statusline.sh` |

---

## 檔案結構

```
susi-status-line-cc/
├── README.md                # 本檔
├── LICENSE                  # MIT
├── .gitignore
├── sushi-statusline.sh      # 主腳本
├── settings.example.json    # settings.json 設定片段範例
├── install.sh               # 印出待貼 JSON（不自動改設定）
├── demo.sh                  # 本機預覽，不動設定
└── assets/
    └── demo.tape            # vhs 錄 GIF 腳本
```

## 命名小註

repo 叫 `susi`（故意留俏皮的拼法），腳本內檔名跟註解用 `sushi`。請勿驚慌，是同一隻壽司。

## 歡迎許願 / 回報

喜歡的話、用起來卡關、想到新口味（拉麵車、啤酒輸送帶、行星軌道？）都歡迎：

- 🐛 bug、平台相容性（Linux / WSL 實測）：[開 issue](https://github.com/tboydar/susi-status-line-cc/issues/new)
- 💡 新功能、新主題、排版想法：一樣開 issue 聊
- 🍣 PR 非常歡迎——特別是 Linux / WSL 的實測回報、新 emoji 主題包

這是小玩具專案，但既然公開了就持續收 feedback 慢慢長大。

## 授權

MIT。詳見 `LICENSE`。
