import type { ReactNode } from 'react'
import { BRAND, brandCssVars } from '@/lib/theme'

export const metadata = {
  title: BRAND.name + ' · ' + BRAND.tagline,
  description: 'VARK × 腦波 EEG × 記憶模型 三源融合語言學習',
}

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="zh-Hant">
      <body>
        <style>{`:root{${brandCssVars()}} body{margin:0;font-family:-apple-system,"PingFang TC",sans-serif}`}</style>
        {children}
      </body>
    </html>
  )
}
