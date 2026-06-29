-- ============================================================
-- MemoLingua · 機構版：記憶天份量表 資料匯出 RPC
-- 提供「依天份篩選」的逐筆資料給後台匯出 CSV（學生分流用）。
-- 只回非個資欄位（天份、指標、在學什麼、時間、來源）——
-- 不含 email（email 在 scale_leads，永遠不對外開放）。
-- 用法：Supabase → SQL Editor → 貼上執行一次。
-- ============================================================
CREATE OR REPLACE FUNCTION public.memory_scale_rows(
  p_top1 text DEFAULT NULL,
  p_limit int DEFAULT 2000
)
RETURNS TABLE(
  created_at timestamptz, top1 text, top2 text,
  in_v numeric, in_a numeric, in_t numeric, in_act numeric,
  learning_target text, source text
)
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT created_at, top1, top2, in_v, in_a, in_t, in_act, learning_target, source
  FROM public.memory_scale_submissions
  WHERE (p_top1 IS NULL OR top1 = p_top1)
  ORDER BY created_at DESC
  LIMIT greatest(1, least(coalesce(p_limit, 2000), 5000));
$$;
GRANT EXECUTE ON FUNCTION public.memory_scale_rows(text, int) TO anon, authenticated, service_role;
