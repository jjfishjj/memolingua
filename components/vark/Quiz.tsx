'use client'
import { useEffect, useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { mapQuestion, VARK_KEYS, VARK_CARDS, type VarkQuestion, type VarkType } from '@/lib/vark'

const EMO: Record<VarkType, string> = { visual:'👁️', auditory:'🎧', reading:'📖', kinesthetic:'🤸' }

export function Quiz({ userId, onDone }: { userId: string; onDone: (sessionId: string) => void }) {
  const supabase = createClient()
  const [qs, setQs] = useState<VarkQuestion[]>([])
  const [i, setI] = useState(0)
  const [ans, setAns] = useState<Record<string, Set<VarkType>>>({})
  const [sessionId] = useState(() => crypto.randomUUID())
  const [busy, setBusy] = useState(false)

  useEffect(() => {
    supabase.from('vark_questions').select('*').eq('language', 'zh').eq('is_active', true).limit(16)
      .then(({ data }) => setQs((data ?? []).map(mapQuestion)))
  }, [])

  if (!qs.length) return <div style={{ padding: 40, textAlign: 'center', color: '#9ca3af' }}>載入題目中…</div>
  const q = qs[i]
  const sel = ans[q.id] ?? new Set()

  const toggle = (t: VarkType) => {
    const n = new Set(sel); n.has(t) ? n.delete(t) : n.add(t)
    setAns({ ...ans, [q.id]: n })
  }

  const next = async () => {
    setBusy(true)
    if (sel.size) {
      await supabase.from('vark_responses').insert(
        [...sel].map(t => ({ user_id: userId, question_id: q.id, selected_type: t, session_id: sessionId })))
    }
    if (i + 1 >= qs.length) {
      await supabase.rpc('calculate_vark_quiz', { p_session_id: sessionId, p_user_id: userId })
      onDone(sessionId)
    } else setI(i + 1)
    setBusy(false)
  }

  const pct = Math.round((i + 1) / qs.length * 100)
  return (
    <div style={{ maxWidth: 460, margin: '0 auto', padding: 20 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 13, color: '#6b7280' }}>
        <span>問題 {i + 1} / {qs.length}</span><span>{pct}%</span>
      </div>
      <div style={{ height: 8, background: '#eef0f3', borderRadius: 99, margin: '8px 0 20px', overflow: 'hidden' }}>
        <div style={{ width: pct + '%', height: '100%', background: 'linear-gradient(90deg,var(--accent),#6366F1)', transition: '.4s' }} />
      </div>
      {q.ctx && <div style={{ fontStyle: 'italic', color: '#9ca3af', fontSize: 13, marginBottom: 6 }}>{q.ctx}</div>}
      <h2 style={{ fontSize: 17 }}>{q.q}</h2>
      <p style={{ color: '#9ca3af', fontSize: 13, margin: '4px 0 14px' }}>可選擇多個答案</p>
      {VARK_KEYS.map(t => {
        const on = sel.has(t)
        return (
          <button key={t} onClick={() => toggle(t)} style={{
            display: 'flex', gap: 11, alignItems: 'flex-start', width: '100%', textAlign: 'left',
            padding: 14, border: `2px solid ${on ? VARK_CARDS[t].color : '#eef0f3'}`,
            background: on ? VARK_CARDS[t].color + '18' : '#fff', borderRadius: 14, marginBottom: 10, cursor: 'pointer',
          }}>
            <span style={{ fontSize: 19 }}>{EMO[t]}</span>
            <span style={{ fontSize: 14, color: '#444' }}>{q.o[t]}</span>
            {on && <span style={{ marginLeft: 'auto', fontWeight: 700 }}>✓</span>}
          </button>
        )
      })}
      <div style={{ display: 'flex', gap: 10, marginTop: 16 }}>
        {i > 0 && <button onClick={() => setI(i - 1)} style={btn(true)}>上一題</button>}
        <button onClick={next} disabled={!sel.size || busy} style={btn(false, !sel.size || busy)}>
          {i + 1 === qs.length ? '看融合結果 →' : '下一題 →'}
        </button>
      </div>
    </div>
  )
}
const btn = (ghost: boolean, disabled = false): React.CSSProperties => ({
  flex: 1, padding: 14, borderRadius: 15, fontSize: 15, fontWeight: 600, cursor: disabled ? 'not-allowed' : 'pointer',
  border: ghost ? '1px solid #e3e6ea' : 'none',
  background: ghost ? '#fff' : disabled ? '#e5e7eb' : 'var(--primary)',
  color: ghost ? '#6b7280' : disabled ? '#aaa' : '#fff',
})
