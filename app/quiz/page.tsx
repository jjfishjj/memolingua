'use client'
export const dynamic = 'force-dynamic'
import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import { Quiz } from '@/components/vark/Quiz'

// 測驗收斂：主測驗已統一為「記憶天賦量表」(8 型)。這個舊版 VARK 測驗保留為備援，
// 但頁面頂端導向正宮，避免使用者重複測 VARK 又測 8 型。
const SCALE_URL = 'https://jjfishjj.github.io/memolingua/scale.html'

export default function QuizPage() {
  const supabase = createClient()
  const router = useRouter()
  const [uid, setUid] = useState<string | null>(null)
  const [showLegacy, setShowLegacy] = useState(false)

  useEffect(() => {
    supabase.auth.getUser().then(({ data }) => {
      if (!data.user) router.push('/login'); else setUid(data.user.id)
    })
  }, [])

  if (!uid) return null

  return (
    <main style={{ maxWidth: 480, margin: '0 auto', padding: 20 }}>
      <a href={SCALE_URL} style={{ textDecoration: 'none' }}>
        <div style={{ background: 'linear-gradient(135deg,#0e3a36,#14b8a6)', color: '#fff', borderRadius: 16, padding: 18 }}>
          <div style={{ fontSize: 30 }}>🧠</div>
          <div style={{ fontWeight: 700, fontSize: 16, marginTop: 4 }}>主測驗：記憶天賦量表（8 型）→</div>
          <div style={{ fontSize: 12, opacity: .9, marginTop: 4 }}>
            我們把測驗統一了。這個 8 型量表更完整，做完會直接得到你的 VARK、個人化學習路線與 30 天計畫。
          </div>
        </div>
      </a>

      {!showLegacy ? (
        <button onClick={() => setShowLegacy(true)}
          style={{ marginTop: 14, width: '100%', padding: 12, border: '1px solid #e3e6ea', borderRadius: 12, background: '#fff', color: '#9ca3af', fontSize: 13, cursor: 'pointer' }}>
          還是想用舊版 VARK 4 型測驗？點這裡
        </button>
      ) : (
        <div style={{ marginTop: 14 }}>
          <p style={{ color: '#9ca3af', fontSize: 12, marginBottom: 4 }}>舊版 VARK 測驗（備援）</p>
          <Quiz userId={uid} onDone={() => router.push('/profile')} />
        </div>
      )}
    </main>
  )
}
