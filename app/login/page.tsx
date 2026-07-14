'use client'
export const dynamic = 'force-dynamic'
import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import { BRAND } from '@/lib/theme'

// Google provider isn't enabled in Supabase yet (Authentication → Providers → Google).
// Flip to true once Client ID/Secret are configured there — no other code change needed.
const GOOGLE_LOGIN_ENABLED = false

export default function LoginPage() {
  const supabase = createClient()
  const router = useRouter()
  const [email, setEmail] = useState('')
  const [pw, setPw] = useState('')
  const [mode, setMode] = useState<'signin' | 'signup'>('signin')
  const [msg, setMsg] = useState('')
  const [busy, setBusy] = useState(false)

  const submit = async () => {
    setBusy(true); setMsg('')
    const fn = mode === 'signin'
      ? supabase.auth.signInWithPassword({ email, password: pw })
      : supabase.auth.signUp({ email, password: pw })
    const { error } = await fn
    setBusy(false)
    if (error) return setMsg('⚠ ' + error.message)
    if (mode === 'signup') return setMsg('✅ 註冊成功！請收信驗證後再登入。')
    router.push('/')
  }

  const google = async () => {
    await supabase.auth.signInWithOAuth({ provider: 'google', options: { redirectTo: location.origin + '/auth/callback' } })
  }

  return (
    <main style={{ maxWidth: 400, margin: '0 auto', padding: '60px 24px', textAlign: 'center' }}>
      <div style={{ fontSize: 48 }}>🧠</div>
      <h1 style={{ color: 'var(--primary)' }}>
        {BRAND.logoText[0]}<span style={{ color: 'var(--accent)' }}>{BRAND.logoText[1]}</span>
      </h1>
      <p style={{ color: '#6b7280', fontSize: 13 }}>{BRAND.tagline}</p>

      <div style={{ display: 'flex', borderRadius: 13, overflow: 'hidden', border: '1px solid #e3e6ea', margin: '28px 0 16px' }}>
        {(['signin', 'signup'] as const).map(m => (
          <button key={m} onClick={() => setMode(m)} style={{ flex: 1, padding: 10, border: 'none', cursor: 'pointer',
            fontSize: 14, background: mode === m ? 'var(--primary)' : '#fff', color: mode === m ? '#fff' : '#6b7280' }}>
            {m === 'signin' ? '登入' : '註冊'}
          </button>
        ))}
      </div>

      <input value={email} onChange={e => setEmail(e.target.value)} placeholder="Email" type="email" style={inp} />
      <input value={pw} onChange={e => setPw(e.target.value)} placeholder="密碼" type="password" style={inp}
        onKeyDown={e => e.key === 'Enter' && submit()} />

      <button onClick={submit} disabled={busy || !email || !pw} style={{ ...btnP, opacity: busy || !email || !pw ? .5 : 1 }}>
        {busy ? '處理中…' : mode === 'signin' ? '登入' : '建立帳號'}
      </button>
      {GOOGLE_LOGIN_ENABLED && <button onClick={google} style={btnG}>使用 Google 登入</button>}
      {msg && <p style={{ fontSize: 13, marginTop: 14, color: msg.startsWith('✅') ? '#10b981' : '#ef4444' }}>{msg}</p>}
    </main>
  )
}
const inp: React.CSSProperties = { width: '100%', border: '1px solid #e3e6ea', borderRadius: 13, padding: '12px 14px', fontSize: 14, marginBottom: 10, outline: 'none' }
const btnP: React.CSSProperties = { width: '100%', padding: 13, border: 'none', borderRadius: 14, background: 'var(--primary)', color: '#fff', fontSize: 15, fontWeight: 600, cursor: 'pointer', marginTop: 4 }
const btnG: React.CSSProperties = { width: '100%', padding: 13, border: '1px solid #e3e6ea', borderRadius: 14, background: '#fff', color: '#374151', fontSize: 14, cursor: 'pointer', marginTop: 10 }
