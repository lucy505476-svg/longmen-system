# 龍門營運系統

規格見 [龍門營運系統 v1 規格書.md](龍門營運系統%20v1%20規格書.md)。

## 本機開發

Node.js 裝在 `~/.local/node`。每次開新的終端機，先執行這兩行（讓終端機找得到 Node，並進到專案資料夾）：

```bash
export PATH="$HOME/.local/node/bin:$PATH"
```

```bash
cd ~/Desktop/longmen-system
```

之後依需要執行（一次貼一行，不要連同說明一起貼）：

| 指令 | 用途 |
| --- | --- |
| `npm install` | 安裝套件（只有第一次或套件有變動時） |
| `npm run db:reset` | 重建本機資料庫並放入假資料 |
| `npm run dev` | 啟動，打開 http://localhost:8787/admin ，按 Ctrl+C 停止 |
| `npm run typecheck` | 型別檢查 |

- 本機開發模式由 `.dev.vars` 的 `DEV_MODE=true` 開啟，後台不需登入；正式環境 `wrangler.toml` 為 `false`，後台會擋下。
- `seed/seed.sql` 全部是虛構資料。
- `data/` 是真實個資，已列入 `.gitignore`，不可推上 GitHub。

## 結構

| 路徑 | 內容 |
| --- | --- |
| `migrations/` | D1 資料表（照規格書第五節） |
| `seed/` | 開發用假資料 |
| `src/index.ts` | Worker 入口 |
| `src/admin.ts` | 後台頁面與 API |
