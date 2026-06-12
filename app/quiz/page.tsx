'use client'
export const dynamic = 'force-dynamic'
import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import { Quiz } from '@/components/vark/Quiz'

export default function QuizPage() {
  const supabase = createClient()
  const router = useRouter()
  const [uid, setUid] = useState<string | null>(null)

  useEffect(() => {
    supabase.auth.getUser().then(({ data }) => {
      if (!data.user) router.push('/login'); else setUid(data.user.id)
    })
  }, [])

  if (!uid) return null
  return <Quiz userId={uid} onDone={() => router.push('/profile')} />
}
