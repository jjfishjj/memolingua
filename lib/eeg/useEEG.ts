'use client'
import { useRef, useState, useCallback } from 'react'
// @ts-ignore — muse.js 為純 JS 模組
import { MuseClient, NeuroSkyClient } from './muse.js'

export interface EEGState {
  engagement: number; cognitiveLoad: number; encodingStrength: number; relaxation: number
  eeg_v: number; eeg_a: number; eeg_r: number; eeg_k: number; signalQuality: number
}

/**
 * useEEG — 連真實頭環(Muse/NeuroSky)或模擬，提供即時 state，並可自動 POST /api/eeg
 */
export function useEEG(opts: { conversationId?: string; autoPost?: boolean } = {}) {
  const [mode, setMode] = useState<'off' | 'real' | 'neuro' | 'sim'>('off')
  const [state, setState] = useState<EEGState | null>(null)
  const [bands, setBands] = useState<any>(null)
  const clientRef = useRef<any>(null)
  const simRef = useRef<any>(null)

  const push = useCallback((b: any, s: EEGState) => {
    setBands(b); setState(s)
    if (opts.autoPost && opts.conversationId) {
      fetch('/api/eeg', { method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ conversation_id: opts.conversationId, bands: b, state: s }) }).catch(() => {})
    }
  }, [opts.autoPost, opts.conversationId])

  const connectMuse = useCallback(async () => {
    const c = new MuseClient()
    let last: any = null
    c.onBands((b: any) => { last = b })
    c.onState((s: EEGState) => push(last, s))
    await c.connect(); clientRef.current = c; setMode('real')
  }, [push])

  const connectNeuro = useCallback(async () => {
    const c = new NeuroSkyClient()
    let last: any = null
    c.onBands((b: any) => { last = b })
    c.onState((s: EEGState) => push(last, s))
    await c.connect(); clientRef.current = c; setMode('neuro')
  }, [push])

  const startSim = useCallback(() => {
    let e = { delta: 8, theta: 22, alpha: 34, beta: 24, gamma: 12 }
    const cl = (x: number, a: number, b: number) => Math.max(a, Math.min(b, x))
    simRef.current = setInterval(() => {
      const j = () => (Math.random() - .5) * 6
      e = { delta: cl(e.delta + j(), 3, 15), theta: cl(e.theta + j(), 12, 35), alpha: cl(e.alpha + j(), 18, 45), beta: cl(e.beta + j(), 12, 38), gamma: cl(e.gamma + j(), 5, 22) }
      const eng = cl(e.beta / (e.alpha + e.theta), 0, 1), load = cl(e.theta / e.alpha * .7, 0, 1), enc = cl(e.theta * e.gamma / 420, 0, 1)
      const sum = e.alpha + (e.theta * .7 + e.alpha * .3) + e.beta + (e.gamma * .6 + e.theta * .4)
      push(e, { engagement: eng, cognitiveLoad: load, encodingStrength: enc, relaxation: cl(e.alpha / e.beta, 0, 1),
        eeg_v: e.alpha / sum, eeg_a: (e.theta * .7 + e.alpha * .3) / sum, eeg_r: e.beta / sum, eeg_k: (e.gamma * .6 + e.theta * .4) / sum, signalQuality: 1 })
    }, 900)
    setMode('sim')
  }, [push])

  const disconnect = useCallback(() => {
    clientRef.current?.disconnect?.(); clientRef.current = null
    clearInterval(simRef.current); simRef.current = null
    setMode('off'); setState(null)
  }, [])

  return { mode, state, bands, connectMuse, connectNeuro, startSim, disconnect }
}
