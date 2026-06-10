'use client'
import { useEffect, useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { RadarChart, Radar, PolarGrid, PolarAngleAxis, PolarRadiusAxis, ResponsiveContainer, Legend, Tooltip } from 'recharts'
import { VARK_CARDS, type VarkType } from '@/lib/vark'

export function FusionRadar({ userId }: { userId: string }) {
  const supabase = createClient()
  const [p, setP] = useState<any>(null)

  useEffect(() => {
    supabase.from('vark_profiles').select('*').eq('user_id', userId).single().then(({ data }) => setP(data))
  }, [userId])

  if (!p) return <div style={{ padding: 40, textAlign: 'center', color: '#9ca3af' }}>分析中…</div>

  const norm = (a: number, b: number, c: number, d: number) => {
    const s = (a + b + c + d) || 1; return [a, b, c, d].map(x => Math.round(x / s * 100))
  }
  const quiz = norm(p.quiz_v, p.quiz_a, p.quiz_r, p.quiz_k)
  const beh  = norm(p.behavior_v, p.behavior_a, p.behavior_r, p.behavior_k)
  const eeg  = norm(p.eeg_v ?? 0, p.eeg_a ?? 0, p.eeg_r ?? 0, p.eeg_k ?? 0)
  const blend = norm(p.blended_v, p.blended_a, p.blended_r, p.blended_k)
  const hasEeg = (p.eeg_v ?? 0) + (p.eeg_a ?? 0) + (p.eeg_r ?? 0) + (p.eeg_k ?? 0) > 0

  const data = ['Visual', 'Auditory', 'Reading', 'Kinesthetic'].map((subject, idx) => ({
    subject, 測驗: quiz[idx], 行為: beh[idx], 腦波: eeg[idx], 融合: blend[idx],
  }))
  const dom = p.dominant_type as VarkType
  const card = dom ? VARK_CARDS[dom] : null

  return (
    <div style={{ maxWidth: 460, margin: '0 auto', padding: 20 }}>
      {card && (
        <div style={{ borderRadius: 20, padding: 20, color: '#fff', background: `linear-gradient(135deg,${card.color}cc,${card.color})`, marginBottom: 14 }}>
          <div style={{ fontSize: 42 }}>{card.emoji}</div>
          <div style={{ opacity: .75, fontSize: 12 }}>三源融合 · 主要學習風格</div>
          <h1 style={{ margin: '4px 0' }}>{card.label}</h1>
          <div style={{ background: 'rgba(255,255,255,.22)', borderRadius: 13, padding: '8px 11px', fontSize: 13, marginTop: 10 }}>
            🧠 {card.bw} · 信賴度 {Math.round((p.confidence ?? (hasEeg ? .88 : .64)) * 100)}%
          </div>
        </div>
      )}
      <div style={{ border: '1px solid #eef0f3', borderRadius: 18, padding: 16 }}>
        <h2 style={{ fontSize: 15 }}>三源融合雷達圖</h2>
        <ResponsiveContainer width="100%" height={280}>
          <RadarChart data={data}>
            <PolarGrid stroke="#f0f0f0" />
            <PolarAngleAxis dataKey="subject" tick={{ fontSize: 12 }} />
            <PolarRadiusAxis domain={[0, 100]} tick={false} axisLine={false} />
            <Radar name="測驗" dataKey="測驗" stroke="#6366F1" fill="#6366F1" fillOpacity={.1} strokeWidth={1.5} />
            <Radar name="行為" dataKey="行為" stroke="#EC4899" fill="#EC4899" fillOpacity={.1} strokeWidth={1.5} />
            {hasEeg && <Radar name="腦波" dataKey="腦波" stroke="#14b8a6" fill="#14b8a6" fillOpacity={.1} strokeWidth={1.5} strokeDasharray="4 3" />}
            <Radar name="融合" dataKey="融合" stroke="#10B981" fill="#10B981" fillOpacity={.2} strokeWidth={2.5} />
            <Legend wrapperStyle={{ fontSize: 11 }} />
            <Tooltip formatter={(v: number) => v + '%'} />
          </RadarChart>
        </ResponsiveContainer>
      </div>
    </div>
  )
}
