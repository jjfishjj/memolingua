'use client'
import { useEffect, useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { fromDB, toDB, review, retrievability, type Rating } from '@/lib/memory/fsrs'

const MOD: Record<string, { c: string; n: string }> = {
  visual: { c:'#6366F1', n:'👁️視覺卡' }, auditory: { c:'#EC4899', n:'🎧語音複習' },
  reading: { c:'#10B981', n:'📖文字卡' }, kinesthetic: { c:'#F59E0B', n:'🤸情境重練' },
}
const RATINGS: { r: Rating; label: string; color: string }[] = [
  { r:1, label:'忘了', color:'#ef4444' }, { r:2, label:'模糊', color:'#f59e0b' },
  { r:3, label:'記得', color:'#10b981' }, { r:4, label:'秒答', color:'#10b981' },
]

export function ReviewDeck({ userId, eegEngagement }: { userId: string; eegEngagement?: number }) {
  const supabase = createClient()
  const [items, setItems] = useState<any[]>([])
  const [toast, setToast] = useState('')

  const load = async () => {
    const { data } = await supabase.from('memory_items').select('*')
      .eq('user_id', userId).lte('next_review_at', new Date().toISOString())
      .order('next_review_at').limit(30)
    setItems(data ?? [])
  }
  useEffect(() => { load() }, [userId])

  const grade = async (item: any, rating: Rating) => {
    const card = fromDB(item)
    const { card: next, interval } = review(card, rating, new Date(), { eegEngagement })
    const patch = toDB(next)
    await supabase.from('memory_items').update(patch).eq('id', item.id)
    await supabase.from('memory_reviews').insert({
      memory_item_id: item.id, user_id: userId, quality: rating,
      review_modality: item.encoding_context, eeg_engagement: eegEngagement ?? null,
    })
    const eng = eegEngagement != null ? `（含腦波專注 ${Math.round(eegEngagement * 100)}%）` : ''
    setToast(`📅 FSRS：下次複習 ${interval} 天後 · 穩定度→${next.stability.toFixed(1)}天 ${eng}`)
    setTimeout(() => setToast(''), 2800)
    setItems(items.filter(x => x.id !== item.id))
  }

  if (!items.length) return <p style={{ textAlign: 'center', padding: 30, color: '#9ca3af' }}>🎉 今日複習已完成！</p>

  return (
    <div style={{ maxWidth: 460, margin: '0 auto', padding: 20 }}>
      <h1>📅 記憶複習中心</h1>
      <p style={{ color: '#6b7280', fontSize: 13 }}>今日待複習 {items.length} 項 · FSRS 排程</p>
      {items.map(item => {
        const card = fromDB(item)
        const mod = MOD[item.encoding_context] ?? MOD.reading
        const ret = Math.round(retrievability(card) * 100)
        return (
          <div key={item.id} style={{ border: '1px solid #eef0f3', borderRadius: 15, padding: 14, marginTop: 12, position: 'relative' }}>
            <div style={{ fontWeight: 700, fontSize: 15 }}>{item.content}</div>
            <div style={{ fontSize: 12, color: '#6b7280' }}>{item.meaning}</div>
            <span style={{ position: 'absolute', top: 12, right: 12, fontSize: 10, padding: '2px 8px', borderRadius: 99, background: mod.c + '22', color: mod.c }}>{mod.n}</span>
            <div style={{ fontSize: 11, color: '#6b7280', marginTop: 8 }}>
              R={ret}% · S={card.stability.toFixed(1)}天 · D={card.difficulty.toFixed(1)}
            </div>
            <div style={{ height: 6, background: '#eef0f3', borderRadius: 99, marginTop: 8, overflow: 'hidden' }}>
              <div style={{ width: ret + '%', height: '100%', background: ret < 50 ? '#ef4444' : mod.c }} />
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4,1fr)', gap: 6, marginTop: 11 }}>
              {RATINGS.map(({ r, label, color }) => (
                <button key={r} onClick={() => grade(item, r)} style={{
                  padding: '9px 4px', border: '1px solid #e3e6ea', borderRadius: 10,
                  fontSize: 12, fontWeight: 600, color, cursor: 'pointer', background: '#fff',
                }}>{label}</button>
              ))}
            </div>
          </div>
        )
      })}
      {toast && (
        <div style={{ position: 'fixed', left: '50%', bottom: 80, transform: 'translateX(-50%)',
          background: 'var(--primary)', color: '#fff', fontSize: 12, padding: '10px 14px', borderRadius: 12,
          maxWidth: '88%', textAlign: 'center', boxShadow: '0 8px 24px rgba(0,0,0,.25)' }}>{toast}</div>
      )}
    </div>
  )
}
