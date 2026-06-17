// Minimal conversation types required by lib/vark-analyzer.ts (ported from fluent-ai).
export type DifficultyLevel = 'beginner' | 'intermediate' | 'advanced'
export type SpeechSpeed = 'slow' | 'normal' | 'fast'
export type ToneStyle = 'formal' | 'semi-formal' | 'casual'
export type ConversationMode = 'practice' | 'test' | 'freeChat'

export interface ConversationSettings {
  language: string
  languageVariant?: string
  scenario: string
  difficulty: DifficultyLevel
  speed: SpeechSpeed
  tone: ToneStyle
  mode: ConversationMode
  instantCorrection?: boolean
  romanization?: boolean
}
