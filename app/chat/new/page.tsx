'use client'
export const dynamic = 'force-dynamic'
import { useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'

export default function NewChat() {
  const router = useRouter()
  const supabase = createClient()

  useEffect(() => {
    (async () => {
      const sp = new URLSearchParams(window.location.search)
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) return router.push('/login')
      const { data } = await supabase.from('conversations').insert({
        user_id: user.id,
        language: sp.get('lang') ?? 'english',
        scenario: sp.get('scenario') ?? 'restaurant',
        difficulty: sp.get('difficulty') ?? 'intermediate',
        speed: 'normal', tone: 'semi-formal', mode: 'practice',
      }).select('id').single()
      if (data) router.replace(`/chat/${data.id}`)
    })()
  }, [])

  return <div style={{ padding: 40, textAlign: 'center', color: '#9ca3af' }}>建立對話中…</div>
}
