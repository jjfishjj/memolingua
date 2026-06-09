# MemoLingua — 真實 App 啟用步驟（Supabase + Claude）

目前 repo 同時含兩種東西：
- **靜態 Demo**：`index.html`（GitHub Pages 直接跑，模擬資料）
- **真實 App 骨架**：Next.js + Supabase + Claude（下面步驟啟用）

## 1. 安裝
```bash
cd memolingua
npm install
cp .env.example .env.local   # 填入你的金鑰
```

## 2. 建 Supabase 專案
1. supabase.com 建專案 → SQL Editor 貼上並執行 `supabase/schema.sql`
2. 再執行 EEG/記憶擴充（見對話中的 ALTER TABLE / FSRS 欄位）
3. Settings → API 複製 URL、anon key、service_role key 填進 `.env.local`
4. Authentication → 開啟 Email 或 Google 登入

## 3. Claude 金鑰
console.anthropic.com 取得 `ANTHROPIC_API_KEY` 填進 `.env.local`

## 4. 部署 Edge Function（腦波寫入也可走 /api/eeg，二擇一）
```bash
supabase functions deploy ingest-eeg
supabase functions deploy analyze-vark-behavior
```

## 5. 本機跑
```bash
npm run dev      # http://localhost:3000
```

## 6. 上線 Vercel
```bash
vercel --prod
# 在 Vercel 專案 Settings → Environment Variables 填入同樣 4 個金鑰
```

## 已接好的真實整合
| 檔案 | 功能 |
|---|---|
| `app/api/chat/route.ts` | Claude 對話，依 VARK 主型 + 即時腦波負荷動態調整教學風格，自動存 messages |
| `app/api/eeg/route.ts` | 接 muse.js/NeuroSky 腦波 → 寫 eeg_sessions → 重算三源融合 vark_profiles |
| `lib/supabase/*` | 瀏覽器 / 伺服器 / service-role client |
| `lib/eeg/muse.js` | 真實頭環，`muse.onState(s => fetch('/api/eeg',{method:'POST',body:JSON.stringify({bands,state:s})}))` |
| `lib/memory/fsrs.ts` | FSRS 排程，搭配 memory_items 表 |

## 前端串接範例
```ts
// 送訊息
const r = await fetch('/api/chat', { method:'POST',
  body: JSON.stringify({ conversationId, history, message }) })
const { reply } = await r.json()

// 推腦波（每秒）
muse.onState(s => fetch('/api/eeg', { method:'POST',
  body: JSON.stringify({ conversation_id, bands, state: s }) }))
```
> 靜態 Demo 的 UI（測驗/雷達圖/記憶複習）可逐步搬成 React 元件接上這些 API。
