// app/api/chat/route.ts — 真實 Claude 對話，依 VARK + 即時腦波負荷調整教學風格
import Anthropic from '@anthropic-ai/sdk'
import { createClient } from '@/lib/supabase/server'
import { NextResponse } from 'next/server'

const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY! })

const VARK_GUIDE: Record<string, string> = {
  visual: '用符號標記 (✅❌📌)、before/after 對比格式呈現修正，描述可想像的畫面。段落短、多換行。',
  auditory: '用自然口語語氣、引導跟讀，強調語音節奏與韻律，用對話範例而非孤立句子。',
  reading: '提供結構化、編號清單的解釋，附文法術語與 2–3 個例句，結尾給文字摘要。',
  kinesthetic: '把每個修正化為任務，要求立即重試；用真實情境包裝，鼓勵做中學。',
}

export async function POST(req: Request) {
  const { conversationId, history = [], message } = await req.json()
  const supabase = createClient()

  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return NextResponse.json({ error: 'unauthorized' }, { status: 401 })

  // 取對話設定 + VARK 輪廓 + 最近腦波負荷
  const [{ data: conv }, { data: vark }, { data: eeg }] = await Promise.all([
    supabase.from('conversations').select('*').eq('id', conversationId).single(),
    supabase.from('vark_profiles').select('*').eq('user_id', user.id).single(),
    supabase.from('eeg_sessions').select('cognitive_load,engagement')
      .eq('user_id', user.id).order('recorded_at', { ascending: false }).limit(1).maybeSingle(),
  ])

  const dom = vark?.dominant_type ?? null
  const load = eeg?.cognitive_load ?? null

  const system = `
你是 MemoLingua 的 AI 語言教師，透過 ${conv?.scenario ?? '日常'} 情境陪使用者練 ${conv?.language ?? 'English'}。
難度 ${conv?.difficulty ?? 'intermediate'}、語氣 ${conv?.tone ?? 'semi-formal'}。

【教學風格】${dom ? VARK_GUIDE[dom] : '尚無 VARK 資料，用均衡多元方式。'}
${load != null && load > 0.6 ? `【即時腦波】偵測到認知負荷偏高(${Math.round(load*100)}%) → 放慢、縮短句子、降低生詞密度，先確認理解再前進。` : ''}

規則：保持情境角色；每回合只糾正一個重點，格式：
✏️ 你說：「...」
✅ 更好：「...」
📌 原因：一句話
糾正後立刻接續對話。回覆長度貼合使用者訊息長度。絕不說「身為 AI」、絕不明說使用者的 VARK 類型。
`.trim()

  const resp = await anthropic.messages.create({
    model: 'claude-sonnet-4-5',
    max_tokens: 800,
    system,
    messages: [...history, { role: 'user', content: message }],
  })
  const text = resp.content[0]?.type === 'text' ? resp.content[0].text : ''

  // 存訊息
  await supabase.from('messages').insert([
    { conversation_id: conversationId, role: 'user', content: message },
    { conversation_id: conversationId, role: 'assistant', content: text },
  ])

  return NextResponse.json({ reply: text })
}
