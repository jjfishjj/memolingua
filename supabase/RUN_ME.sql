-- ============================================================
-- MemoLingua · 一次跑完所有待補 DB 修正（2026-07-07 整併）
-- 內容：① genius 欄位 ② 後台上鎖（admins + is_admin + RPC 收權）
--       ③ 公開計數 RPC ④ 清除測試資料
-- 用法：Supabase SQL Editor 貼上全部 → Run（可重複執行）。
-- ============================================================

-- ① 量表寫入 genius（fluent-ai 對照型態）
ALTER TABLE public.memory_scale_submissions ADD COLUMN IF NOT EXISTS genius text;

-- ② 管理員白名單 + is_admin()
CREATE TABLE IF NOT EXISTS public.admins (
  user_id    uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.admins ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT EXISTS (SELECT 1 FROM public.admins WHERE user_id = auth.uid());
$$;
REVOKE EXECUTE ON FUNCTION public.is_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_admin() TO anon, authenticated;

-- ③ 公開總數（前台「你是第 N 位」用，只回一個數字）
CREATE OR REPLACE FUNCTION public.memory_scale_public_count()
RETURNS integer LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT count(*)::int FROM public.memory_scale_submissions WHERE source NOT LIKE 'selftest%';
$$;
GRANT EXECUTE ON FUNCTION public.memory_scale_public_count() TO anon, authenticated, service_role;

-- ② 續：後台統計上鎖（管理員限定）
CREATE OR REPLACE FUNCTION public.memory_scale_stats()
RETURNS json LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'forbidden: admin only' USING ERRCODE = '42501'; END IF;
  RETURN (SELECT json_build_object(
    'total', (SELECT count(*) FROM public.memory_scale_submissions),
    'last_7d', (SELECT count(*) FROM public.memory_scale_submissions WHERE created_at >= now() - interval '7 days'),
    'by_top1', (SELECT coalesce(json_object_agg(top1, c), '{}'::json)
      FROM (SELECT top1, count(*) c FROM public.memory_scale_submissions GROUP BY top1) d),
    'combos', (SELECT coalesce(json_agg(json_build_object('combo', combo, 'count', c) ORDER BY c DESC), '[]'::json)
      FROM (SELECT (top1 || ' + ' || coalesce(top2,'-')) AS combo, count(*) c
            FROM public.memory_scale_submissions GROUP BY 1 ORDER BY c DESC LIMIT 12) t),
    'avg_input', (SELECT json_build_object('v', round(avg(in_v)::numeric,3), 'a', round(avg(in_a)::numeric,3),
      't', round(avg(in_t)::numeric,3), 'act', round(avg(in_act)::numeric,3)) FROM public.memory_scale_submissions),
    'by_target', (SELECT coalesce(json_agg(json_build_object('target', target, 'count', c) ORDER BY c DESC), '[]'::json)
      FROM (SELECT nullif(lower(trim(learning_target)), '') AS target, count(*) c
            FROM public.memory_scale_submissions WHERE nullif(lower(trim(learning_target)), '') IS NOT NULL
            GROUP BY 1 ORDER BY c DESC LIMIT 20) t),
    'recent', (SELECT coalesce(json_agg(json_build_object('top1', top1, 'top2', top2, 'target', learning_target, 'at', created_at) ORDER BY created_at DESC), '[]'::json)
      FROM (SELECT top1, top2, learning_target, created_at FROM public.memory_scale_submissions ORDER BY created_at DESC LIMIT 12) r)
  ));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.memory_scale_stats() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.memory_scale_stats() TO authenticated;

-- ② 續：逐筆匯出上鎖
CREATE OR REPLACE FUNCTION public.memory_scale_rows(p_top1 text DEFAULT NULL, p_limit int DEFAULT 2000)
RETURNS TABLE(created_at timestamptz, top1 text, top2 text,
  in_v numeric, in_a numeric, in_t numeric, in_act numeric, learning_target text, source text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'forbidden: admin only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
    SELECT s.created_at, s.top1, s.top2, s.in_v, s.in_a, s.in_t, s.in_act, s.learning_target, s.source
    FROM public.memory_scale_submissions s
    WHERE (p_top1 IS NULL OR s.top1 = p_top1)
    ORDER BY s.created_at DESC
    LIMIT greatest(1, least(coalesce(p_limit, 2000), 5000));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.memory_scale_rows(text, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.memory_scale_rows(text, int) TO authenticated;

-- ② 續：名單筆數上鎖
CREATE OR REPLACE FUNCTION public.scale_leads_count()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'forbidden: admin only' USING ERRCODE = '42501'; END IF;
  RETURN (SELECT count(*)::int FROM public.scale_leads);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.scale_leads_count() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.scale_leads_count() TO authenticated;

-- 簡易量表統計一併上鎖（若存在）
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname='public_vark_stats') THEN
    EXECUTE 'REVOKE EXECUTE ON FUNCTION public.public_vark_stats() FROM PUBLIC, anon';
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.public_vark_stats() TO authenticated';
  END IF;
END $$;

-- ④ 清除測試資料
DELETE FROM public.memory_scale_submissions WHERE source LIKE 'selftest%';
DELETE FROM public.scale_leads WHERE source LIKE 'selftest%' OR email = 'selftest@example.com';

-- ⑤ 把你自己設成管理員（此 email 需已在 App 註冊過）
INSERT INTO public.admins (user_id)
SELECT id FROM auth.users WHERE email = 'guocheju@gmail.com'
ON CONFLICT (user_id) DO NOTHING;

-- 驗證：應回 admins_count >= 1、genius 欄位存在
SELECT (SELECT count(*) FROM public.admins) AS admins_count,
       EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_name='memory_scale_submissions' AND column_name='genius') AS genius_column_ok;
