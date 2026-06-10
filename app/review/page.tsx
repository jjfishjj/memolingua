'use client'
import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import { ReviewDeck } from '@/components/memory/ReviewDeck'

export default function ReviewPage() {
  const supabase = createClient()
  const router = useRouter()
  const [uid, setUid] = useState<string | null>(null)

  useEffect(() => {
    supabase.auth.getUser().then(({ data }) => {
      if (!data.user) router.push('/login'); else setUid(data.user.id)
    })
  }, [])

  if (!uid) return null
  // eegEngagement 可由父層注入即時腦波；此處先不帶
  return <ReviewDeck userId={uid} />
}
