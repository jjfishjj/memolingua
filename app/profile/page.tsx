'use client'
export const dynamic = 'force-dynamic'
import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import { FusionRadar } from '@/components/vark/FusionRadar'

export default function ProfilePage() {
  const supabase = createClient()
  const router = useRouter()
  const [uid, setUid] = useState<string | null>(null)

  useEffect(() => {
    supabase.auth.getUser().then(({ data }) => {
      if (!data.user) router.push('/login'); else setUid(data.user.id)
    })
  }, [])

  if (!uid) return null
  return (
    <div>
      <FusionRadar userId={uid} />
      <div style={{ maxWidth: 460, margin: '0 auto', padding: '0 20px 40px' }}>
        <button onClick={() => router.push('/review')} style={{ width: '100%', padding: 14, borderRadius: 15, background: 'var(--accent)', color: '#fff', border: 'none', fontWeight: 600, cursor: 'pointer' }}>
          📅 前往記憶複習 →
        </button>
      </div>
    </div>
  )
}
