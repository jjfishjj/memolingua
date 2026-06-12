// lib/supabase/client.ts — 瀏覽器端 Supabase client
import { createBrowserClient } from '@supabase/ssr'

// 注意：NEXT_PUBLIC_* 會在 build 時被內聯。若 build 當下變數缺失（例如靜態
// 預渲染階段），用佔位值避免 createBrowserClient 直接 throw 導致建構失敗；
// 真實環境變數存在時仍會被正確內聯到瀏覽器端。
const URL = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://placeholder.supabase.co'
const KEY = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || 'placeholder-anon-key'

export function createClient() {
  return createBrowserClient(URL, KEY)
}
