-- ============================================================
-- MemoLingua · 記憶天份量表 蒐集（scale.html 用）
-- 匿名訪客填完 → 寫入 memory_scale_submissions
-- 後台 admin-scale.html 只透過 memory_scale_stats() 看彙總。
-- 用法：Supabase → SQL Editor → 貼上執行一次。可重複執行。
-- ============================================================

CREATE TABLE IF NOT EXISTS public.memory_scale_submissions (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at      timestamptz NOT NULL DEFAULT now(),
  top1            text NOT NULL,   -- 主導天份 key: img/snd/txt/act/soc/sys/cre/biz
  top2            text,            -- 次要天份 key
  scores          jsonb,           -- 八大天份原始得分
  in_v numeric, in_a numeric, in_t numeric, in_act numeric,  -- 輸入偏好 視覺/聽覺/文字/動作
  learning_target text,
  source          text NOT NULL DEFAULT 'github-pages'
);
CREATE INDEX IF NOT EXISTS idx_msub_created ON public.memory_scale_submissions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_msub_top1 ON public.memory_scale_submissions(top1);

ALTER TABLE public.memory_scale_submissions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS msub_insert_anyone ON public.memory_scale_submissions;
CREATE POLICY msub_insert_anyone ON public.memory_scale_submissions
  FOR INSERT TO anon, authenticated WITH CHECK (true);
-- 不建 SELECT policy → 前端讀不到個別資料列。

CREATE OR REPLACE FUNCTION public.memory_scale_stats()
RETURNS json LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT json_build_object(
    'total', (SELECT count(*) FROM public.memory_scale_submissions),
    'last_7d', (SELECT count(*) FROM public.memory_scale_submissions WHERE created_at >= now() - interval '7 days'),
    'by_top1', (SELECT coalesce(json_object_agg(top1, c), '{}'::json)
      FROM (SELECT top1, count(*) c FROM public.memory_scale_submissions GROUP BY top1) d),
    'combos', (SELECT coalesce(json_agg(json_build_object('combo', combo, 'count', c) ORDER BY c DESC), '[]'::json)
      FROM (SELECT (top1 || ' + ' || coalesce(top2,'-')) AS combo, count(*) c
            FROM public.memory_scale_submissions GROUP BY 1 ORDER BY c DESC LIMIT 12) t),
    'avg_input', (SELECT json_build_object(
      'v', round(avg(in_v)::numeric,3), 'a', round(avg(in_a)::numeric,3),
      't', round(avg(in_t)::numeric,3), 'act', round(avg(in_act)::numeric,3))
      FROM public.memory_scale_submissions),
    'by_target', (SELECT coalesce(json_agg(json_build_object('target', target, 'count', c) ORDER BY c DESC), '[]'::json)
      FROM (SELECT nullif(lower(trim(learning_target)), '') AS target, count(*) c
            FROM public.memory_scale_submissions WHERE nullif(lower(trim(learning_target)), '') IS NOT NULL
            GROUP BY 1 ORDER BY c DESC LIMIT 20) t),
    'recent', (SELECT coalesce(json_agg(json_build_object('top1', top1, 'top2', top2, 'target', learning_target, 'at', created_at) ORDER BY created_at DESC), '[]'::json)
      FROM (SELECT top1, top2, learning_target, created_at FROM public.memory_scale_submissions ORDER BY created_at DESC LIMIT 12) r)
  );
$$;
GRANT EXECUTE ON FUNCTION public.memory_scale_stats() TO anon, authenticated, service_role;
