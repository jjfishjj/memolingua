-- ============================================================
-- MemoLingua · 記憶天份量表 email 名單（CTA 用）
-- scale.html 報告底部留 email → 寫入 scale_leads。
-- email 為個資：只允許匿名「寫入」，沒有任何 SELECT policy
-- → 前端 anon key 讀不到任何名單，只能從 Supabase 後台/後端讀。
-- 用法：Supabase → SQL Editor → 貼上執行一次。
-- ============================================================

CREATE TABLE IF NOT EXISTS public.scale_leads (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at      timestamptz NOT NULL DEFAULT now(),
  email           text NOT NULL,
  top1            text,
  top2            text,
  learning_target text,
  source          text NOT NULL DEFAULT 'scale'
);
CREATE INDEX IF NOT EXISTS idx_scale_leads_created ON public.scale_leads(created_at DESC);

ALTER TABLE public.scale_leads ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS scale_leads_insert_anyone ON public.scale_leads;
CREATE POLICY scale_leads_insert_anyone ON public.scale_leads
  FOR INSERT TO anon, authenticated WITH CHECK (true);
-- 沒有 SELECT policy：名單只能在 Supabase Dashboard（service_role）看，前端讀不到。

-- 後台只需要「名單筆數」可公開（不洩漏 email 本身）
CREATE OR REPLACE FUNCTION public.scale_leads_count()
RETURNS integer LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT count(*)::int FROM public.scale_leads;
$$;
GRANT EXECUTE ON FUNCTION public.scale_leads_count() TO anon, authenticated, service_role;
