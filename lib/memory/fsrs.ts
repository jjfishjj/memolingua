/**
 * fsrs.ts — FSRS v4 (Free Spaced Repetition Scheduler)
 * 比 SM-2 更準的記憶排程：用「難度 D + 穩定度 S + 可提取性 R」三變數模型。
 * 並擴充支援 EEG 編碼強度，作為新項目的初始穩定度加成。
 *
 * 參考：Jarrett Ye 的 FSRS 開源權重。下方為預設 17 維權重 (w0..w16)。
 */

export type Rating = 1 | 2 | 3 | 4   // Again / Hard / Good / Easy
export interface FSRSCard {
  stability: number      // S：記憶穩定度（天）
  difficulty: number     // D：難度 1~10
  due: Date              // 下次到期
  lastReview: Date | null
  reps: number
  lapses: number
  state: 'new' | 'learning' | 'review' | 'relearning'
}

// FSRS-4.5 預設權重
const W = [
  0.4072, 1.1829, 3.1262, 15.4722, 7.2102, 0.5316, 1.0651, 0.0234, 1.616,
  0.1544, 1.0824, 1.9813, 0.0953, 0.2975, 2.2042, 0.2407, 2.9466,
]
const DECAY = -0.5
const FACTOR = Math.pow(0.9, 1 / DECAY) - 1   // 使 R=0.9 時 t=S

/** 目標保留率（可調，越高複習越頻繁） */
const REQUEST_RETENTION = 0.9

export function newCard(): FSRSCard {
  return { stability: 0, difficulty: 0, due: new Date(), lastReview: null, reps: 0, lapses: 0, state: 'new' }
}

/** 可提取性 R(t)：距上次複習 t 天後還記得的機率 */
export function retrievability(card: FSRSCard, now: Date = new Date()): number {
  if (!card.lastReview || card.stability <= 0) return 0
  const t = (now.getTime() - card.lastReview.getTime()) / 86400_000
  return Math.pow(1 + FACTOR * t / card.stability, DECAY)
}

/** 由穩定度求下次間隔（天），達到目標保留率 */
function nextInterval(stability: number): number {
  const ivl = (stability / FACTOR) * (Math.pow(REQUEST_RETENTION, 1 / DECAY) - 1)
  return Math.max(1, Math.round(ivl))
}

function initStability(rating: Rating): number {
  return Math.max(0.1, W[rating - 1])
}
function initDifficulty(rating: Rating): number {
  return clamp(W[4] - Math.exp(W[5] * (rating - 1)) + 1, 1, 10)
}
function nextDifficulty(D: number, rating: Rating): number {
  const next = D - W[6] * (rating - 3)
  // 均值回歸
  return clamp(W[7] * initDifficulty(4) + (1 - W[7]) * next, 1, 10)
}
function nextStabilityRecall(D: number, S: number, R: number, rating: Rating): number {
  const hardPenalty = rating === 2 ? W[15] : 1
  const easyBonus   = rating === 4 ? W[16] : 1
  return S * (1 + Math.exp(W[8]) * (11 - D) * Math.pow(S, -W[9]) *
    (Math.exp((1 - R) * W[10]) - 1) * hardPenalty * easyBonus)
}
function nextStabilityForget(D: number, S: number, R: number): number {
  return W[11] * Math.pow(D, -W[12]) * (Math.pow(S + 1, W[13]) - 1) * Math.exp((1 - R) * W[14])
}

export interface ReviewOpts {
  eegEncoding?: number    // 0~1，新卡編碼當下的腦波 Theta-Gamma 耦合
  eegEngagement?: number  // 0~1，複習當下專注度（微調有效難度）
}

/**
 * 複習一張卡 → 回傳更新後的卡 + 本次間隔
 */
export function review(card: FSRSCard, rating: Rating, now: Date = new Date(), opts: ReviewOpts = {}): { card: FSRSCard; intervalDays: number } {
  const next: FSRSCard = { ...card, reps: card.reps + 1, lastReview: now }

  // EEG 專注度微調：高專注時把 Hard→Good 之類略升一級的效果（不改使用者評分，只調 R 計算）
  const engAdj = opts.eegEngagement != null ? (opts.eegEngagement - 0.5) * 0.1 : 0

  if (card.state === 'new') {
    next.difficulty = initDifficulty(rating)
    next.stability  = initStability(rating)
    // ⭐ EEG 編碼加成：編碼越強，初始穩定度越高（記得越久）
    if (opts.eegEncoding != null) {
      next.stability *= (1 + opts.eegEncoding * 0.6)   // 最多 +60%
    }
    next.state = rating === 1 ? 'learning' : 'review'
  } else {
    const R = clamp(retrievability(card, now) + engAdj, 0, 1)
    next.difficulty = nextDifficulty(card.difficulty, rating)
    if (rating === 1) {
      next.stability = nextStabilityForget(card.difficulty, card.stability, R)
      next.lapses += 1
      next.state = 'relearning'
    } else {
      next.stability = nextStabilityRecall(card.difficulty, card.stability, R, rating)
      next.state = 'review'
    }
  }

  const intervalDays = nextInterval(next.stability)
  next.due = new Date(now.getTime() + intervalDays * 86400_000)
  return { card: next, intervalDays }
}

/** 取今日到期卡 */
export function getDueCards<T extends { fsrs: FSRSCard }>(cards: T[], now = new Date()): T[] {
  return cards.filter(c => c.fsrs.due.getTime() <= now.getTime())
}

const clamp = (x: number, a: number, b: number) => Math.max(a, Math.min(b, x))

/* ----------------------------------------------------------
 * 與 Supabase memory_items 對接：欄位映射
 *   stability  -> memory_strength 可由 retrievability 換算
 *   difficulty -> easiness 的取代（FSRS 用 D，不用 SM-2 的 EF）
 * 建議在 memory_items 增加欄位：
 *   ALTER TABLE memory_items ADD COLUMN fsrs_stability NUMERIC DEFAULT 0;
 *   ALTER TABLE memory_items ADD COLUMN fsrs_difficulty NUMERIC DEFAULT 0;
 *   ALTER TABLE memory_items ADD COLUMN fsrs_state TEXT DEFAULT 'new';
 *   ALTER TABLE memory_items ADD COLUMN lapses INTEGER DEFAULT 0;
 * -------------------------------------------------------- */
export function toDB(card: FSRSCard) {
  return {
    fsrs_stability: card.stability,
    fsrs_difficulty: card.difficulty,
    fsrs_state: card.state,
    lapses: card.lapses,
    repetitions: card.reps,
    next_review_at: card.due.toISOString(),
    last_reviewed_at: card.lastReview?.toISOString() ?? null,
  }
}
export function fromDB(row: any): FSRSCard {
  return {
    stability: row.fsrs_stability ?? 0,
    difficulty: row.fsrs_difficulty ?? 0,
    state: row.fsrs_state ?? 'new',
    lapses: row.lapses ?? 0,
    reps: row.repetitions ?? 0,
    due: new Date(row.next_review_at),
    lastReview: row.last_reviewed_at ? new Date(row.last_reviewed_at) : null,
  }
}
