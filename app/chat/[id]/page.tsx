'use client'
export const dynamic = 'force-dynamic'
import { useEffect, useState } from 'react'
import { useParams, useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import { ChatRoom } from '@/components/chat/ChatRoom'

export default function ChatPage() {
  const { id } = useParams<{ id: string }>()
  const router = useRouter()
  const supabase = createClient()
  const [ok, setOk] = useState(false)

  useEffect(() => {
    supabase.auth.getUser().then(({ data }) => {
      if (!data.user) router.push('/login'); else setOk(true)
    })
  }, [])

  if (!ok) return null
  return <ChatRoom conversationId={id} />
}
