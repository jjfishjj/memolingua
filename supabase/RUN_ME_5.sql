-- ============================================================
-- MemoLingua · 後台 #2：時間序列 + 轉換漏斗
-- ① admin_activity_series：每日填答/訓練事件趨勢（畫折線圖）
-- ② admin_funnel：量表完成 → 留 email → 點導流（看流失）
-- ③ 補漏斗的 demo 資料（scale_leads + 導流點擊）讓圖表馬上有東西
-- 前提：RUN_ME.sql（is_admin）、RUN_ME_2.sql（play_events）、RUN_ME_3.sql（demo）
-- 用法：SQL Editor 貼上 → Run（可重複執行）
-- ============================================================

-- ① 每日活動時間序列（近 N 天，補零，管理員限定）
CREATE OR REPLACE FUNCTION public.admin_activity_series(p_days int DEFAULT 30)
RETURNS json LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'forbidden: admin only' USING ERRCODE='42501'; END IF;
  RETURN (
    SELECT coalesce(json_agg(json_build_object('d', to_char(d,'MM/DD'), 'quiz', q, 'train', t) ORDER BY d), '[]'::json)
    FROM (
      SELECT gs::date AS d,
        (SELECT count(*) FROM public.memory_scale_submissions m
           WHERE m.created_at::date = gs::date AND m.source NOT LIKE 'selftest%') AS q,
        (SELECT count(*) FROM public.play_events p
           WHERE p.created_at::date = gs::date AND p.source NOT LIKE 'selftest%'
             AND p.exercise_id <> '__toapp__') AS t
      FROM generate_series(now()::date - (greatest(1,least(p_days,90))-1), now()::date, interval '1 day') gs
    ) x
  );
END;$$;
REVOKE EXECUTE ON FUNCTION public.admin_activity_series(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_activity_series(int) TO authenticated;

-- ② 轉換漏斗
CREATE OR REPLACE FUNCTION public.admin_funnel()
RETURNS json LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'forbidden: admin only' USING ERRCODE='42501'; END IF;
  RETURN json_build_object(
    'quiz_done',    (SELECT count(*) FROM public.memory_scale_submissions WHERE source NOT LIKE 'selftest%'),
    'email_leads',  (SELECT count(*) FROM public.scale_leads WHERE source NOT LIKE 'selftest%'),
    'toapp_clicks', (SELECT count(*) FROM public.play_events WHERE exercise_id='__toapp__' AND source NOT LIKE 'selftest%')
  );
END;$$;
REVOKE EXECUTE ON FUNCTION public.admin_funnel() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_funnel() TO authenticated;

-- ③ 補漏斗 demo 資料（source='demo'，之後跟其他 demo 一起清）
DELETE FROM public.scale_leads WHERE source='demo';
DELETE FROM public.play_events WHERE exercise_id='__toapp__' AND source='demo';

-- 45 筆假 email 名單（量表完成 120 → 留 email 45，約 37% 轉換）
INSERT INTO public.scale_leads (created_at,email,top1,top2,learning_target,source)
SELECT now() - (random()*30||' days')::interval,
  'demo'||gs||'@example.com',
  (ARRAY['img','snd','txt','act','soc','sys','cre','biz'])[1+floor(random()*8)::int],
  (ARRAY['img','snd','txt','act','soc','sys','cre','biz'])[1+floor(random()*8)::int],
  (ARRAY['英文','多益','日文','雅思'])[1+floor(random()*4)], 'demo'
FROM generate_series(1,45) gs;

-- 72 筆導流點擊（留 email 45 之外，也有人沒留 email 直接點 → 72，約 60% 點擊）
INSERT INTO public.play_events (created_at,exercise_id,mode,talent,event,source)
SELECT now() - (random()*30||' days')::interval,
  '__toapp__','funnel',
  (ARRAY['img','snd','txt','act','soc','sys','cre','biz'])[1+floor(random()*8)::int],
  'open','demo'
FROM generate_series(1,72);

-- 驗證
SELECT public.admin_funnel() AS 漏斗;
