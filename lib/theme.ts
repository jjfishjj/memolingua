/**
 * theme.ts — 全站品牌單一來源 (Single Source of Truth)
 * 改這一個檔，全站配色 / 名稱 / 文案語氣即時生效。
 * 之後你提供品牌色票 / Logo / App 名，只需替換下方 BRAND 物件。
 *
 * 目前為「中性預設品牌」：深藍 + 青色。
 */

export const BRAND = {
  // ── 識別 ──
  name: 'MemoLingua',                  // App 名
  logoText: ['Memo', 'Lingua'],        // [前段, 高亮段]；若用圖檔改 logoSrc
  logoSrc: null as string | null,      // 例：'/logo.svg'
  tagline: '用腦波學語言，記得更牢 🧠',

  // ── 主色系（青綠科技感）──
  colors: {
    primary:   '#0e3a36',   // 主色（深青綠）— 按鈕、標題
    accent:    '#14b8a6',   // 強調色（青綠）— EEG / CTA
    // VARK 四型固定語意色（保留，辨識度高）
    visual:      '#6366F1',
    auditory:    '#EC4899',
    reading:     '#10B981',
    kinesthetic: '#F59E0B',
    // 中性（微帶青綠）
    ink:  '#0e3a36',
    sub:  '#6b7280',
    line: '#e7eeec',
    bg:   '#f3f8f7',
  },

  // ── 文案語氣 ──
  // tone: 'lively'(活潑) | 'professional'(專業) | 'minimal'(簡約)
  tone: 'lively' as 'lively' | 'professional' | 'minimal',
}

/** 文案依語氣切換 */
const COPY = {
  lively: {
    quizStart: '來測測你是哪型學霸！🎉',
    reportTitle: '你的學習超能力解鎖 ✨',
    chatEnd: '太棒啦，看看你拿到什麼回饋 👀',
    memoryTitle: '該複習囉！別讓記憶溜走 🏃',
  },
  professional: {
    quizStart: '開始學習風格評估',
    reportTitle: '三源融合學習風格報告',
    chatEnd: '結束對話並查看回饋報表',
    memoryTitle: '記憶複習中心',
  },
  minimal: {
    quizStart: '開始測驗',
    reportTitle: '學習風格',
    chatEnd: '結束',
    memoryTitle: '複習',
  },
}
export const t = COPY[BRAND.tone]

/** 注入 CSS 變數（在 RootLayout 呼叫一次） */
export function brandCssVars(): string {
  const c = BRAND.colors
  return `
    --primary:${c.primary};--accent:${c.accent};
    --v:${c.visual};--a:${c.auditory};--r:${c.reading};--k:${c.kinesthetic};
    --ink:${c.ink};--sub:${c.sub};--line:${c.line};--bg:${c.bg};
    --eeg:${c.accent};
  `.replace(/\s+/g, '')
}

/* 用法（Next.js）：
   // app/layout.tsx
   import { brandCssVars, BRAND } from '@/lib/theme'
   <html><body><style>{`:root{${brandCssVars()}}`}</style>...</body></html>

   // 任何元件
   import { BRAND, t } from '@/lib/theme'
   <h1>{t.reportTitle}</h1>
   <span style={{color:'var(--primary)'}}>{BRAND.name}</span>
*/
