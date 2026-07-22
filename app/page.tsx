'use client'
export const dynamic = 'force-dynamic'
import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import { BRAND } from '@/lib/theme'
import { VARK_CARDS, type VarkType } from '@/lib/vark'

const NAV = [
  { href: '/quiz',     icon: '📝', title: 'VARK 測驗',   desc: '找出你的學習風格' },
  { href: '/profile',  icon: '🧠', title: '融合報告',     desc: '三源雷達圖與信賴度' },
  { href: '/chat/new', icon: '💬', title: '開始對話',     desc: 'AI 陪練 + 即時腦波' },
  { href: '/review',   icon: '📅', title: '記憶複習',     desc: 'FSRS 智慧排程' },
  { href: '/brain-lab', icon: '🧪', title: 'Brain Lab',   desc: '腦波 × 2-Back × 素材庫' },
]

export default function Home() {
  const supabase = createClient()
  const router = useRouter()
  const [user, setUser] = useState<any>(null)
  const [vark, setVark] = useState<any>(null)
  const [due, setDue] = useState(0)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    (async () => {
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) { router.push('/login'); return }
      setUser(user)
      const [{ data: v }, { count }] = await Promise.all([
        supabase.from('vark_profiles').select('*').eq('user_id', user.id).maybeSingle(),
        supabase.from('memory_items').select('*', { count: 'exact', head: true })
          .eq('user_id', user.id).lte('next_review_at', new Date().toISOString()),
      ])
      setVark(v); setDue(count ?? 0); setLoading(false)
    })()
  }, [])

  if (loading) return <div style={{ padding: 60, textAlign: 'center', color: '#9ca3af' }}>載入中…</div>

  const dom = vark?.dominant_type as VarkType | undefined
  const card = dom ? VARK_CARDS[dom] : null

  return (
    <main style={{ maxWidth: 480, margin: '0 auto', padding: 20 }}>
      <header style={{ display: 'flex', alignItems: 'center', marginBottom: 18 }}>
        <div style={{ fontWeight: 800, fontSize: 18, color: 'var(--primary)' }}>
          {BRAND.logoText[0]}<span style={{ color: 'var(--accent)' }}>{BRAND.logoText[1]}</span>
        </div>
        <button onClick={async () => { await supabase.auth.signOut(); router.push('/login') }}
          style={{ marginLeft: 'auto', fontSize: 12, color: '#9ca3af', background: 'none', border: 'none', cursor: 'pointer' }}>登出</button>
      </header>

      <a href="https://fluent-ai-mu.vercel.app" style={{ textDecoration: 'none' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, background: 'linear-gradient(135deg,#0e3a36,#14b8a6)', color: '#fff', borderRadius: 14, padding: '12px 14px', marginBottom: 14 }}>
          <span style={{ fontSize: 22 }}>🚀</span>
          <div style={{ flex: 1 }}>
            <div style={{ fontWeight: 700, fontSize: 14 }}>前往完整版 App</div>
            <div style={{ fontSize: 12, opacity: .9 }}>Brain Lab · 多科目 · 社交陪練 · 可裝成手機 App</div>
          </div>
          <span style={{ fontSize: 18 }}>→</span>
        </div>
      </a>

      <p style={{ color: '#6b7280', fontSize: 14 }}>嗨，{user.email?.split('@')[0]} 👋 今天也來練一下吧！</p>

      {card ? (
        <div style={{ borderRadius: 18, padding: 16, color: '#fff', marginTop: 12,
          background: `linear-gradient(135deg,${card.color}cc,${card.color})` }}>
          <div style={{ fontSize: 30 }}>{card.emoji}</div>
          <div style={{ opacity: .8, fontSize: 12 }}>你的學習風格</div>
          <div style={{ fontWeight: 700, fontSize: 18 }}>{card.label}</div>
          <div style={{ fontSize: 12, opacity: .85, marginTop: 4 }}>🧠 {card.bw}</div>
        </div>
      ) : (
        <div style={{ borderRadius: 18, padding: 16, marginTop: 12, background: '#f3f8f7', border: '1px solid #d7ebe7' }}>
          <b style={{ color: 'var(--primary)' }}>還沒測過 VARK！</b>
          <p style={{ fontSize: 13, color: '#6b7280', margin: '4px 0 10px' }}>花 2 分鐘，解鎖個人化 AI 教學 🚀</p>
          <button onClick={() => router.push('/quiz')} style={{ padding: '10px 16px', border: 'none', borderRadius: 12, background: 'var(--accent)', color: '#fff', fontWeight: 600, cursor: 'pointer' }}>立即測驗</button>
        </div>
      )}

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginTop: 16 }}>
        {NAV.map(n => (
          <button key={n.href} onClick={() => router.push(n.href)} style={{
            textAlign: 'left', border: '1px solid #eef0f3', borderRadius: 16, padding: 16, background: '#fff', cursor: 'pointer' }}>
            <div style={{ fontSize: 26 }}>{n.icon}</div>
            <div style={{ fontWeight: 700, fontSize: 14, marginTop: 6, color: 'var(--primary)' }}>{n.title}</div>
            <div style={{ fontSize: 11, color: '#9ca3af', marginTop: 2 }}>{n.desc}</div>
            {n.href === '/review' && due > 0 && (
              <span style={{ display: 'inline-block', marginTop: 8, fontSize: 11, background: '#fef2f2', color: '#ef4444', padding: '2px 8px', borderRadius: 99 }}>{due} 項待複習</span>
            )}
          </button>
        ))}
      </div>
    </main>
  )
}
