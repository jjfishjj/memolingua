'use client'
// Lightweight toast shim — replaces shadcn/radix toast used in fluent-ai.
// Brain Lab only needs simple feedback on device connect/fail.
type ToastInput = {
  title?: string
  description?: string
  variant?: 'default' | 'destructive'
}

export function useToast() {
  const toast = (t: ToastInput) => {
    const msg = [t.title, t.description].filter(Boolean).join('\n')
    if (typeof window !== 'undefined' && msg) {
      // Non-blocking notice; destructive variants are worth surfacing.
      if (t.variant === 'destructive') console.warn('[toast]', msg)
      else console.info('[toast]', msg)
      window.alert(msg)
    }
  }
  return { toast }
}
