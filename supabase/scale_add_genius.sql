-- ============================================================
-- MemoLingua · 記憶天份量表：加 genius 欄位（對照 fluent-ai 型態）
-- 讓中央資料同時存 memolingua 型態(top1)與對照後的 fluent-ai genius 型，
-- 方便跨兩套系統分析 / 導流。
-- 用法：Supabase → SQL Editor → 貼上執行一次。
-- ============================================================
ALTER TABLE public.memory_scale_submissions
  ADD COLUMN IF NOT EXISTS genius text;
