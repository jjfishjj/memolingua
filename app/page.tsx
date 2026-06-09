import { BRAND } from '@/lib/theme'

export default function Home() {
  return (
    <main style={{ maxWidth: 480, margin: '0 auto', padding: '60px 24px', textAlign: 'center' }}>
      <div style={{ fontSize: 54 }}>🧠</div>
      <h1 style={{ color: 'var(--primary)' }}>
        {BRAND.logoText[0]}<span style={{ color: 'var(--accent)' }}>{BRAND.logoText[1]}</span>
      </h1>
      <p style={{ color: '#6b7280' }}>{BRAND.tagline}</p>
      <p style={{ color: '#9ca3af', fontSize: 13, marginTop: 24 }}>
        真實 App 骨架已就緒。API：<code>/api/chat</code>、<code>/api/eeg</code>。<br />
        互動 Demo 請見 <a href="https://jjfishjj.github.io/memolingua/">GitHub Pages</a>。
      </p>
    </main>
  )
}
