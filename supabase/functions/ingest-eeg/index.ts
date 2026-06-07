// supabase/functions/ingest-eeg/index.ts
// 接收前端 muse.js 推來的腦波匯總，寫入 eeg_sessions，並重算三源融合 VARK 輪廓。
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })

  const { user_id, conversation_id, bands, state, device = 'muse', duration_sec } = await req.json()
  if (!user_id || !bands || !state) {
    return new Response(JSON.stringify({ error: 'missing fields' }), { status: 400, headers: cors })
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )

  // 1. 寫入腦波 session
  await supabase.from('eeg_sessions').insert({
    user_id, conversation_id, device, duration_sec,
    delta: bands.delta, theta: bands.theta, alpha: bands.alpha, beta: bands.beta, gamma: bands.gamma,
    engagement: state.engagement, cognitive_load: state.cognitiveLoad,
    encoding_strength: state.encodingStrength, relaxation: state.relaxation,
    eeg_v: state.eeg_v, eeg_a: state.eeg_a, eeg_r: state.eeg_r, eeg_k: state.eeg_k,
    signal_quality: state.signalQuality,
  })

  // 2. 更新 vark_profiles 的 EEG 欄位（近 7 天平均）
  const { data: recent } = await supabase
    .from('eeg_sessions')
    .select('eeg_v,eeg_a,eeg_r,eeg_k,cognitive_load,signal_quality,recorded_at')
    .eq('user_id', user_id)
    .gte('recorded_at', new Date(Date.now() - 7 * 86400_000).toISOString())

  if (recent?.length) {
    const avg = (k: string) => recent.reduce((s, r) => s + (r[k] ?? 0), 0) / recent.length
    await supabase.from('vark_profiles').upsert({
      user_id,
      eeg_v: avg('eeg_v'), eeg_a: avg('eeg_a'), eeg_r: avg('eeg_r'), eeg_k: avg('eeg_k'),
      avg_cognitive_load: avg('cognitive_load'),
    }, { onConflict: 'user_id' })

    // 3. 觸發三源重算（quiz 30% + behavior 40% + eeg 30%）
    await supabase.rpc('refresh_vark_profile', { p_user_id: user_id })
    // 4. 更新最佳學習時段
    await supabase.rpc('compute_best_learning_hour', { p_user_id: user_id })
  }

  return new Response(JSON.stringify({ ok: true }), { headers: { ...cors, 'Content-Type': 'application/json' } })
})
