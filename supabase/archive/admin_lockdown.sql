-- ============================================================
-- MemoLingua · 後台上鎖（管理員白名單）
-- 把「看統計 / 匯出」收回 anon，改為：登入 + 在 admins 名單。
-- 訪客「填問卷 / 留 email」不受影響（那是 INSERT，不在此處）。
-- 用法：Supabase → SQL Editor → 貼上執行一次。
-- ⚠️ 最後一步：把你自己加進 admins（見檔尾）。
-- ============================================================

-- 1) 管理員白名單
CREATE TABLE IF NOT EXISTS public.admins (
  user_id    uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.admins ENABLE ROW LEVEL SECURITY;  -- 不給任何 policy → 前端讀不到名單

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT EXISTS (SELECT 1 FROM public.admins WHERE user_id = auth.uid());
$$;
REVOKE EXECUTE ON FUNCTION public.is_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_admin() TO anon, authenticated;  -- 回 true/false，可公開呼叫

-- 2) 公開「總數」給前台量表顯示「你是第 N 位」（非敏感，僅一個數字）
CREATE OR REPLACE FUNCTION public.memory_scale_public_count()
RETURNS integer LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT count(*)::int FROM public.memory_scale_submissions;
$$;
GRANT EXECUTE ON FUNCTION public.memory_scale_public_count() TO anon, authenticated, service_role;

-- 3) 後台統計：加管理員守門 + 收回 anon
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

-- 4) 逐筆匯出：加管理員守門 + 收回 anon
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

-- 5) 名單筆數：加管理員守門 + 收回 anon
CREATE OR REPLACE FUNCTION public.scale_leads_count()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'forbidden: admin only' USING ERRCODE = '42501'; END IF;
  RETURN (SELECT count(*)::int FROM public.scale_leads);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.scale_leads_count() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.scale_leads_count() TO authenticated;

-- （第一個簡易量表的 public_vark_stats 若存在也一併上鎖；不存在可忽略此段）
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname='public_vark_stats') THEN
    EXECUTE 'REVOKE EXECUTE ON FUNCTION public.public_vark_stats() FROM PUBLIC, anon';
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.public_vark_stats() TO authenticated';
  END IF;
END $$;

-- ============================================================
-- ⚠️ 最後一步：把你自己設成管理員
-- 先用你的帳號在 App 註冊/登入過一次（auth.users 才有這筆），再跑：
-- ============================================================
INSERT INTO public.admins (user_id)
SELECT id FROM auth.users WHERE email = 'guocheju@gmail.com'
ON CONFLICT (user_id) DO NOTHING;
-- 想加更多管理員：把上面 email 換掉再跑一次即可。
