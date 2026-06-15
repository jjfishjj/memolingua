// lib/supabase/client.ts — 瀏覽器端 Supabase client
import { createBrowserClient } from '@supabase/ssr'

// NEXT_PUBLIC_* 於 build 時內聯。為避免靜態預渲染階段因變數缺失或格式錯誤
// 而讓 createBrowserClient 直接 throw（導致 next build 失敗），這裡做嚴格驗證：
// URL 必須是合法 http(s)，否則退回佔位值。真實且正確的值仍會被正確內聯。
const RAW_URL = (process.env.NEXT_PUBLIC_SUPABASE_URL || '').trim()
const RAW_KEY = (process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || '').trim()
const URL = /^https?:\/\/[^\s]+$/.test(RAW_URL) ? RAW_URL : 'https://placeholder.supabase.co'
const KEY = RAW_KEY || 'placeholder-anon-key'

export function createClient() {
  return createBrowserClient(URL, KEY)
}
