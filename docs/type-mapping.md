# 型態對照表 · memolingua ↔ fluent-ai

> ⚠️ **正本（single source of truth）= `type-map.json`**
> （線上：https://jjfishjj.github.io/memolingua/type-map.json）
> 要改型態對應，**只改那個 JSON**。`scale.html` 與 `play.html` 載入時會 fetch 它覆蓋內建值。
> fluent-ai 端的 `src/lib/genius-type.ts` 是硬編碼，請手動與此 JSON 保持一致。
> 下面的表格僅供閱讀，若與 JSON 不符，**以 JSON 為準**。

兩個專案分工（memolingua = 獲客官網量表、fluent-ai = 產品 App），
各自維持自己的 8 型態命名，透過這張**對照表**串接資料與導流。

## 對照（8 ↔ 8 雙射）

| memolingua（記憶天份） | key | → fluent-ai（genius） | key | VARK |
|---|---|---|---|---|
| 💠 圖像建構者 | `img` | 🔶 圖像家 VISIONARY | `visionary` | visual |
| 🎧 聲音模仿者 | `snd` | 🟠 旋律人 MELODIST | `melodist` | auditory |
| 📑 文字整理者 | `txt` | 🟣 建築師 ARCHITECT | `architect` | reading |
| 🎯 情境行動者 | `act` | 🔵 探索者 EXPLORER | `explorer` | kinesthetic |
| 🗣️ 社交輸出者 | `soc` | 🌸 表演者 PERFORMER | `performer` | auditory |
| 📈 系統累積者 | `sys` | 🔴 分析師 ANALYST | `analyst` | reading |
| ✨ 創意連結者 | `cre` | 🟡 敘事者 NARRATOR | `narrator` | auditory |
| 💼 商業應用者 | `biz` | 🟢 織網者 CONNECTOR | `connector` | reading |

真實來源：`scale.html` 的 `GENIUS` 常數。

## 導流路徑（獲客官網 → App）

`scale.html` 報告頁的「🚀 到 App 用你的天份開始學」按鈕連到：

```
https://fluent-ai-mu.vercel.app/practice?genius=<genius>&vark=<vark>&from=scale
```

### fluent-ai 需要接收這個參數（Lovable 端加一次）

fluent-ai 目前只從同源 `localStorage.memo_genius_result` 讀型態。
要讓外部量表導流生效，在 App 入口（如 `App.tsx` 或 `main.tsx`）開頭加：

```ts
// 從外部獲客量表導流：?genius=&vark= → 寫入 localStorage 供 loadGeniusType() 讀取
(() => {
  const p = new URLSearchParams(location.search);
  const g = p.get('genius'), v = p.get('vark');
  const VALID = ['explorer','architect','melodist','narrator','connector','analyst','performer','visionary'];
  if (g && VALID.includes(g)) {
    localStorage.setItem('memo_genius_result', JSON.stringify({ p: g, vark: v || undefined, src: 'scale' }));
  }
})();
```

加完後：使用者在 memolingua 官網做完量表 → 點按鈕 → 進 fluent-ai App，
`loadGeniusType()` / `loadGeniusVark()` 立刻讀到型態，Practice AI 直接個人化。

## 中央資料

`memory_scale_submissions` 已加 `genius` 欄位（見 `supabase/scale_add_genius.sql`），
每筆填答同時存 memolingua 型態與對照後的 genius，後台/分析可跨系統彙總。
