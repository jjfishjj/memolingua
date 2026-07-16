-- ============================================================
-- MemoLingua · 訓練行為追蹤（play.html → 後台）
-- 目的：後台除了「誰測出什麼天賦」，也要看得到「誰練了什麼、哪張卡最受歡迎」。
-- 這是機構版分流最值錢的資料。
-- 用法：Supabase → SQL Editor → 貼上全部 → Run（可重複執行）。
-- ============================================================

-- 1) 訓練事件表（完全匿名：沒有 email、沒有姓名、沒有 user id）
CREATE TABLE IF NOT EXISTS public.play_events (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at  timestamptz NOT NULL DEFAULT now(),
  exercise_id text NOT NULL,                    -- play.html 的卡片 id，如 palace / rap
  mode        text,                             -- ai / card / game / sound / similar / tool
  talent      text,                             -- 使用者天賦（img/snd/...），可為 null
  event       text NOT NULL,                    -- 'open' 開啟 | 'complete' 完成
  score_v     numeric,                          -- 分數數值（用來算平均）
  score_t     text,                             -- 分數顯示，如 "6/6"
  source      text NOT NULL DEFAULT 'github-pages'
);
CREATE INDEX IF NOT EXISTS idx_play_created ON public.play_events(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_play_ex ON public.play_events(exercise_id);

ALTER TABLE public.play_events ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS play_insert_anyone ON public.play_events;
CREATE POLICY play_insert_anyone ON public.play_events
  FOR INSERT TO anon, authenticated WITH CHECK (true);
-- 不建 SELECT policy → 前端寫得進、讀不到，只能透過下面的管理員 RPC 看彙總。

-- 2) 訓練行為統計（管理員限定，沿用 RUN_ME.sql 建立的 is_admin()）
CREATE OR REPLACE FUNCTION public.play_stats()
RETURNS json LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'forbidden: admin only' USING ERRCODE = '42501'; END IF;
  RETURN (SELECT json_build_object(
    'total_opens',    (SELECT count(*) FROM public.play_events WHERE event='open'    AND source NOT LIKE 'selftest%'),
    'total_completes',(SELECT count(*) FROM public.play_events WHERE event='complete' AND source NOT LIKE 'selftest%'),
    'last_7d',        (SELECT count(*) FROM public.play_events WHERE created_at >= now() - interval '7 days' AND source NOT LIKE 'selftest%'),
    -- 最受歡迎的卡：依開啟次數排序，附完成次數與平均分
    'top_cards', (SELECT coalesce(json_agg(json_build_object(
        'id', exercise_id, 'mode', mode, 'opens', opens, 'completes', completes, 'avg', avg_v) ORDER BY opens DESC), '[]'::json)
      FROM (
        SELECT exercise_id,
               max(mode) AS mode,
               count(*) FILTER (WHERE event='open') AS opens,
               count(*) FILTER (WHERE event='complete') AS completes,
               round(avg(score_v) FILTER (WHERE score_v IS NOT NULL), 2) AS avg_v
        FROM public.play_events
        WHERE source NOT LIKE 'selftest%'
        GROUP BY exercise_id
        ORDER BY count(*) FILTER (WHERE event='open') DESC
        LIMIT 25) t),
    -- 各訓練形式的熱度
    'by_mode', (SELECT coalesce(json_object_agg(mode, c), '{}'::json)
      FROM (SELECT coalesce(mode,'unknown') AS mode, count(*) c
            FROM public.play_events WHERE source NOT LIKE 'selftest%' GROUP BY 1) d),
    -- 哪種天賦的人比較會來練
    'by_talent', (SELECT coalesce(json_object_agg(talent, c), '{}'::json)
      FROM (SELECT talent, count(*) c FROM public.play_events
            WHERE talent IS NOT NULL AND source NOT LIKE 'selftest%' GROUP BY 1) d),
    -- 完全沒人練過的卡（產品要改進的地方）
    'recent', (SELECT coalesce(json_agg(json_build_object(
        'id', exercise_id, 'event', event, 'talent', talent, 'score', score_t, 'at', created_at) ORDER BY created_at DESC), '[]'::json)
      FROM (SELECT exercise_id, event, talent, score_t, created_at FROM public.play_events
            WHERE source NOT LIKE 'selftest%' ORDER BY created_at DESC LIMIT 15) r)
  ));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.play_stats() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.play_stats() TO authenticated;

-- 3) 訓練行為逐筆匯出（機構分流用；不含任何個資）
CREATE OR REPLACE FUNCTION public.play_rows(p_exercise text DEFAULT NULL, p_limit int DEFAULT 2000)
RETURNS TABLE(created_at timestamptz, exercise_id text, mode text, talent text, event text, score_t text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'forbidden: admin only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
    SELECT e.created_at, e.exercise_id, e.mode, e.talent, e.event, e.score_t
    FROM public.play_events e
    WHERE (p_exercise IS NULL OR e.exercise_id = p_exercise)
      AND e.source NOT LIKE 'selftest%'
    ORDER BY e.created_at DESC
    LIMIT greatest(1, least(coalesce(p_limit, 2000), 5000));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.play_rows(text, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.play_rows(text, int) TO authenticated;

-- 驗證：應回 play_events 表已存在、兩個 RPC 已建立
SELECT
  EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='play_events') AS table_ok,
  EXISTS (SELECT 1 FROM pg_proc WHERE proname='play_stats') AS stats_rpc_ok,
  EXISTS (SELECT 1 FROM pg_proc WHERE proname='play_rows')  AS rows_rpc_ok;
