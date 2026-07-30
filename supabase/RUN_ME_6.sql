-- ============================================================
-- MemoLingua · CDM-lite Stage 1：知識精熟度答題事件表
-- play.html 的遊戲每答一題就送一筆（哪個能力屬性、對或錯）。
-- 個人雷達是純 localStorage（免登入、免這張表也能跑）；
-- 這張表是給「後台全班平均精熟度」(Stage 2) 用的。
-- 完全匿名：沒有 email/姓名/user id。
-- 用法：Supabase → SQL Editor → 貼上 → Run（可重複執行）。
-- ============================================================

CREATE TABLE IF NOT EXISTS public.skill_attempts (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  attr       text NOT NULL,          -- V詞彙 / G文法語序 / L聽辨 / S語義辨析
  correct    boolean NOT NULL,
  talent     text,
  source     text NOT NULL DEFAULT 'github-pages'
);
CREATE INDEX IF NOT EXISTS idx_skill_attr ON public.skill_attempts(attr);
CREATE INDEX IF NOT EXISTS idx_skill_created ON public.skill_attempts(created_at DESC);

ALTER TABLE public.skill_attempts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS skill_insert_anyone ON public.skill_attempts;
CREATE POLICY skill_insert_anyone ON public.skill_attempts
  FOR INSERT TO anon, authenticated WITH CHECK (true);
-- 不建 SELECT policy → 前端寫得進、讀不到。Stage 2 會加管理員 RPC 算全班平均。

SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='skill_attempts') AS table_ok;
