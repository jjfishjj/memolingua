# FluentAI — VARK × 腦波EEG × 記憶模型 語言學習系統

三源融合（測驗 / 對話行為 / 腦波）的個人化語言學習平台，含 FSRS 間隔複習。

## 📁 已交付檔案

```
fluentai/
├── lib/
│   ├── eeg/muse.js              真實腦波串接 (Muse2 / Muse S / NeuroSky, Web Bluetooth)
│   ├── memory/fsrs.ts           FSRS v4.5 間隔複習演算法 (含 EEG 編碼加成)
│   └── theme.ts                 品牌單一來源 (改一檔全站生效)
├── supabase/functions/
│   └── ingest-eeg/index.ts      腦波資料寫入 + 三源融合重算 Edge Function
├── vercel.json                  部署設定 (含 Bluetooth Permissions-Policy)
└── README.md
```
> 另外前面對話已提供：完整 SQL schema、VARK 題庫、AI system prompt、Next.js 頁面、Admin 後台、行為分析 Edge Function。

---

## 🔌 1. 接真實腦波裝置

```js
import { MuseClient } from '@/lib/eeg/muse'

const muse = new MuseClient()
await muse.connect()                    // 跳出藍牙配對視窗 (需 HTTPS 或 localhost)
muse.onBands(b => console.log(b))       // {delta,theta,alpha,beta,gamma}
muse.onState(async s => {
  // s = {engagement, cognitiveLoad, encodingStrength, relaxation, eeg_v/a/r/k, signalQuality}
  await fetch('/api/eeg', { method:'POST', body: JSON.stringify({ user_id, bands, state: s }) })
})
```
- **Muse**：Web Bluetooth 直連，自做 FFT → band power。Chrome/Edge 桌面版支援。
- **NeuroSky MindWave**：用 `NeuroSkyClient`，透過 ThinkGear Connector (ws://127.0.0.1:13854)，裝置已直接給頻段。
- ⚠️ Web Bluetooth 僅在 **HTTPS** 或 **localhost** 可用 → 部署到 Vercel 自動有 HTTPS。

## 🧮 2. FSRS 升級

```ts
import { newCard, review, getDueCards, retrievability } from '@/lib/memory/fsrs'

let card = newCard()
// 新學項目，帶入腦波編碼強度 → 編碼越強初始記憶越牢
;({ card } = review(card, 3, new Date(), { eegEncoding: 0.82 }))

// 之後複習，帶入當下專注度微調
;({ card } = review(card, 4, new Date(), { eegEngagement: 0.7 }))

retrievability(card)   // 當下還記得的機率 0~1
```
需在 `memory_items` 加欄位（SQL 註解已寫在 fsrs.ts 底部）。

## 🚀 3. 部署到 Vercel

```bash
cd fluentai
npm i -g vercel
vercel login
vercel              # 首次部署 (preview)
vercel --prod       # 正式上線

# 設定環境變數
vercel env add NEXT_PUBLIC_SUPABASE_URL
vercel env add NEXT_PUBLIC_SUPABASE_ANON_KEY
vercel env add ANTHROPIC_API_KEY
```
**純 Demo HTML 版**（無後端）更簡單：把 `fluentai-vark-eeg-demo.html` 改名 `index.html` 丟到 GitHub repo → Vercel/GitHub Pages 一鍵發佈。

## 🔗 4. 真實串接

```
前端 muse.js ──POST──▶ /api/eeg ──▶ Edge Function ingest-eeg
                                         │
                          eeg_sessions ◀─┘
                                         │
                          refresh_vark_profile() ← 三源融合 (quiz30/behavior40/eeg30)
                                         │
                          vark_profiles (含 confidence, best_learning_hour)
                                         │
              build-system-prompt.ts ◀───┘ → Claude API 動態調整教學風格
```
部署 Edge Function：
```bash
supabase functions deploy ingest-eeg
supabase functions deploy analyze-vark-behavior
```

## 🎨 5. 品牌客製

改 `lib/theme.ts` 的 `BRAND` 物件即可：
```ts
export const BRAND = {
  name: '你的App名',
  logoText: ['你的', '品牌'],     // 或 logoSrc: '/logo.svg'
  colors: { primary:'#你的主色', accent:'#你的強調色', ... },
  tone: 'lively',                 // 文案語氣：lively / professional / minimal
}
```
> VARK 四型色 (V藍/A粉/R綠/K橙) 建議保留，辨識度高。目前用中性預設（深藍+青）。
> **把你的色票 / Logo / App 名給我，我直接幫你填好。**
