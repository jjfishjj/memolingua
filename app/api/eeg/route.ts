// app/api/eeg/route.ts — 接收 muse.js / NeuroSky 推來的腦波，寫入並重算三源融合
import { createClient, createServiceClient } from '@/lib/supabase/server'
import { NextResponse } from 'next/server'

export async function POST(req: Request) {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return NextResponse.json({ error: 'unauthorized' }, { status: 401 })

  const { conversation_id, bands, state, device = 'muse', duration_sec } = await req.json()
  if (!bands || !state) return NextResponse.json({ error: 'missing' }, { status: 400 })

  const admin = createServiceClient()
  await admin.from('eeg_sessions').insert({
    user_id: user.id, conversation_id, device, duration_sec,
    delta: bands.delta, theta: bands.theta, alpha: bands.alpha, beta: bands.beta, gamma: bands.gamma,
    engagement: state.engagement, cognitive_load: state.cognitiveLoad,
    encoding_strength: state.encodingStrength, relaxation: state.relaxation,
    eeg_v: state.eeg_v, eeg_a: state.eeg_a, eeg_r: state.eeg_r, eeg_k: state.eeg_k,
    signal_quality: state.signalQuality,
  })

  // 近 7 天 EEG 平均 → vark_profiles，並觸發三源融合重算
  const since = new Date(Date.now() - 7 * 864e5).toISOString()
  const { data: recent } = await admin.from('eeg_sessions')
    .select('eeg_v,eeg_a,eeg_r,eeg_k,cognitive_load').eq('user_id', user.id).gte('recorded_at', since)
  if (recent?.length) {
    const avg = (k: string) => recent.reduce((s, r: any) => s + (r[k] ?? 0), 0) / recent.length
    await admin.from('vark_profiles').upsert({
      user_id: user.id, eeg_v: avg('eeg_v'), eeg_a: avg('eeg_a'),
      eeg_r: avg('eeg_r'), eeg_k: avg('eeg_k'), avg_cognitive_load: avg('cognitive_load'),
    }, { onConflict: 'user_id' })
    await admin.rpc('refresh_vark_profile', { p_user_id: user.id })
  }
  return NextResponse.json({ ok: true })
}
