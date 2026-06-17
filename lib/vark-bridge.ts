// lib/vark-bridge.ts
// Bridges Brain Lab's VARKProfile (lib/vark-analyzer) to MemoLingua's
// Supabase `vark_profiles` table (the canonical, cross-device source
// populated by the quiz + behavior + EEG fusion).
//
// Falls back to the localStorage profile (lib/vark-service) when there is
// no DB row, no auth, or the DB is unreachable — so Brain Lab keeps working
// offline / for guests.
import { createClient } from '@/lib/supabase/client'
import { VARKProfile, EMPTY_VARK_PROFILE } from '@/lib/vark-analyzer'
import { loadVARKProfile as loadLocalProfile } from '@/lib/vark-service'

/**
 * Loads the VARK profile for a user, preferring Supabase's blended (three-source)
 * scores and falling back to the local profile.
 */
export async function loadVARKProfileBridged(userId: string): Promise<VARKProfile> {
  if (!userId || userId === 'guest') return loadLocalProfile(userId || 'guest')

  try {
    const supabase = createClient()
    const { data, error } = await supabase
      .from('vark_profiles')
      .select('blended_v, blended_a, blended_r, blended_k, conversation_count')
      .eq('user_id', userId)
      .maybeSingle()

    if (error || !data) return loadLocalProfile(userId)

    const v = Number(data.blended_v ?? 0)
    const a = Number(data.blended_a ?? 0)
    const r = Number(data.blended_r ?? 0)
    const k = Number(data.blended_k ?? 0)
    const total = v + a + r + k

    // No usable DB scores yet → fall back to whatever is stored locally.
    if (total <= 0) return loadLocalProfile(userId)

    return {
      ...EMPTY_VARK_PROFILE,
      scores: { visual: v, auditory: a, reading: r, kinesthetic: k },
      totalSignals: Math.round(total),
      conversationCount: Number(data.conversation_count ?? 0),
      lastUpdated: new Date().toISOString(),
    }
  } catch {
    return loadLocalProfile(userId)
  }
}
