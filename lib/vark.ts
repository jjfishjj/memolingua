// lib/vark.ts — 共用 VARK 常數與題庫（前端用）
export type VarkType = 'visual' | 'auditory' | 'reading' | 'kinesthetic'

export const VARK_CARDS: Record<VarkType, {
  emoji: string; label: string; color: string; bw: string; tips: string[]; ai: string
}> = {
  visual:      { emoji:'👁️', label:'視覺型學習者', color:'#6366F1', bw:'Alpha 波 8–12 Hz', tips:['用心智圖整理單字','看影片注意字幕排版','把規則畫成圖表'], ai:'AI 用符號標記、before/after 對比、描述可想像的畫面。' },
  auditory:    { emoji:'🎧', label:'聽覺型學習者', color:'#EC4899', bw:'Theta–Alpha 4–12 Hz', tips:['朗讀並錄音回聽','用Podcast沉浸','注意語調節奏'], ai:'AI 用對話語氣、引導跟讀、強調語音節奏。' },
  reading:     { emoji:'📖', label:'讀寫型學習者', color:'#10B981', bw:'Beta 13–30 Hz', tips:['建立單字筆記本','閱讀後寫摘要','研究文法邏輯'], ai:'AI 提供結構化解釋、編號清單、多個例句。' },
  kinesthetic: { emoji:'🤸', label:'體驗型學習者', color:'#F59E0B', bw:'Gamma–Theta', tips:['角色扮演練對話','模擬真實情境','修正當任務立即重試'], ai:'AI 把修正化為任務、要求立即重試、以真實情境包裝。' },
}

export interface VarkQuestion {
  id: string; ctx?: string; q: string
  o: Record<VarkType, string>
}

// 對應 DB vark_questions 的列映射
export function mapQuestion(row: any): VarkQuestion {
  return { id: row.id, ctx: row.context ?? undefined, q: row.question_text,
    o: { visual: row.option_v, auditory: row.option_a, reading: row.option_r, kinesthetic: row.option_k } }
}

export const VARK_KEYS: VarkType[] = ['visual', 'auditory', 'reading', 'kinesthetic']
