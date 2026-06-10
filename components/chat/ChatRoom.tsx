'use client'
import { useEffect, useRef, useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { useEEG } from '@/lib/eeg/useEEG'

interface Msg { role: 'user' | 'assistant'; content: string }

export function ChatRoom({ conversationId }: { conversationId: string }) {
  const supabase = createClient()
  const [conv, setConv] = useState<any>(null)
  const [msgs, setMsgs] = useState<Msg[]>([])
  const [input, setInput] = useState('')
  const [sending, setSending] = useState(false)
  const bottom = useRef<HTMLDivElement>(null)
  const eeg = useEEG({ conversationId, autoPost: true })

  useEffect(() => {
    Promise.all([
      supabase.from('conversations').select('*').eq('id', conversationId).single(),
      supabase.from('messages').select('role,content').eq('conversation_id', conversationId).order('created_at'),
    ]).then(([{ data: c }, { data: m }]) => {
      setConv(c); setMsgs((m ?? []).filter((x: any) => x.role !== 'system') as Msg[])
    })
  }, [conversationId])

  useEffect(() => { bottom.current?.scrollIntoView({ behavior: 'smooth' }) }, [msgs])

  const send = async () => {
    const text = input.trim(); if (!text || sending) return
    setInput(''); setSending(true)
    const history = msgs.map(m => ({ role: m.role, content: m.content }))
    setMsgs(m => [...m, { role: 'user', content: text }])
    const r = await fetch('/api/chat', { method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ conversationId, history, message: text }) })
    const { reply } = await r.json()
    setMsgs(m => [...m, { role: 'assistant', content: reply ?? '(無回應)' }])
    setSending(false)
  }

  const pickEEG = async () => {
    if (eeg.mode !== 'off') return eeg.disconnect()
    const p = prompt('腦波來源：1=Muse  2=NeuroSky  3=模擬', '1')
    try {
      if (p === '1') await eeg.connectMuse()
      else if (p === '2') await eeg.connectNeuro()
      else if (p === '3') eeg.startSim()
    } catch (e: any) { if (confirm('連線失敗，用模擬？')) eeg.startSim() }
  }

  const s = eeg.state
  const loadHigh = s && s.cognitiveLoad > 0.6

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100vh', maxWidth: 480, margin: '0 auto' }}>
      <header style={{ padding: '13px 16px', borderBottom: '1px solid #eef0f3', display: 'flex', alignItems: 'center', gap: 8 }}>
        <div>
          <div style={{ fontWeight: 700, fontSize: 14 }}>{conv?.scenario ?? '對話'}</div>
          <div style={{ fontSize: 11, color: '#6b7280' }}>{conv?.language} · {conv?.difficulty}</div>
        </div>
        <button onClick={pickEEG} style={{ marginLeft: 'auto', fontSize: 11, padding: '5px 10px', borderRadius: 20, border: 'none', cursor: 'pointer',
          background: eeg.mode === 'off' ? '#ecfeff' : '#14b8a6', color: eeg.mode === 'off' ? '#0e7490' : '#fff' }}>
          {eeg.mode === 'off' ? '🧠 連頭環' : eeg.mode === 'real' ? '🔵 Muse' : eeg.mode === 'neuro' ? '🟣 NeuroSky' : '🟡 模擬'}
        </button>
      </header>

      {s && (
        <div style={{ padding: '7px 16px', background: '#0f172a', color: '#cbd5e1', fontSize: 11, display: 'flex', gap: 10 }}>
          <span style={{ color: '#22c55e' }}>● EEG</span>
          <span>專注 <b>{Math.round(s.engagement * 100)}%</b></span>
          <span>負荷 <b>{Math.round(s.cognitiveLoad * 100)}%</b></span>
          <span>編碼 <b>{Math.round(s.encodingStrength * 100)}%</b></span>
          <span style={{ marginLeft: 'auto', color: loadHigh ? '#f87171' : s.encodingStrength > .6 ? '#34d399' : '#fbbf24' }}>
            {loadHigh ? '⚠ 負荷偏高' : s.encodingStrength > .6 ? '✨ 編碼活躍' : '● 良好'}
          </span>
        </div>
      )}

      <div style={{ flex: 1, overflowY: 'auto', padding: 14 }}>
        {msgs.map((m, i) => (
          <div key={i} style={{ display: 'flex', justifyContent: m.role === 'user' ? 'flex-end' : 'flex-start', marginBottom: 9 }}>
            <div style={{ maxWidth: '82%', padding: '11px 13px', borderRadius: 17, fontSize: 14, whiteSpace: 'pre-wrap',
              background: m.role === 'user' ? 'var(--primary)' : '#fff', color: m.role === 'user' ? '#fff' : '#374151',
              border: m.role === 'user' ? 'none' : '1px solid #eef0f3',
              borderBottomRightRadius: m.role === 'user' ? 5 : 17, borderBottomLeftRadius: m.role === 'user' ? 17 : 5 }}>
              {m.content}
            </div>
          </div>
        ))}
        {sending && <div style={{ color: '#9ca3af', fontSize: 13, padding: 8 }}>AI 思考中…</div>}
        {loadHigh && <div style={{ background: '#fef2f2', border: '1px solid #fecaca', color: '#b91c1c', fontSize: 12, padding: '9px 12px', borderRadius: 12, margin: '4px 0' }}>
          🧠 認知負荷偏高，AI 將自動放慢、縮短句子
        </div>}
        <div ref={bottom} />
      </div>

      <div style={{ display: 'flex', gap: 8, padding: 12, borderTop: '1px solid #eef0f3' }}>
        <input value={input} onChange={e => setInput(e.target.value)}
          onKeyDown={e => e.key === 'Enter' && send()} placeholder="輸入英文訊息…"
          style={{ flex: 1, border: '1px solid #e3e6ea', borderRadius: 13, padding: '11px 13px', fontSize: 14, outline: 'none' }} />
        <button onClick={send} disabled={sending} style={{ padding: '0 17px', border: 'none', background: 'var(--primary)', color: '#fff', borderRadius: 13, fontWeight: 600, cursor: 'pointer' }}>送出</button>
      </div>
    </div>
  )
}
