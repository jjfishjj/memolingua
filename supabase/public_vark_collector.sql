-- ============================================================
-- MemoLingua · 公開 VARK 量表蒐集（GitHub Pages Demo 用）
-- 匿名訪客填完測驗 → 寫入 public_vark_submissions
-- 後台只透過 public_vark_stats() 看「彙總統計」，看不到個別資料列。
--
-- 用法：Supabase → SQL Editor → 貼上執行一次。可重複執行。
-- ============================================================

-- ---------- 蒐集表 ----------
CREATE TABLE IF NOT EXISTS public.public_vark_submissions (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at      timestamptz NOT NULL DEFAULT now(),
  dominant        text NOT NULL CHECK (dominant IN ('visual','auditory','reading','kinesthetic')),
  secondary       text,
  score_v integer NOT NULL DEFAULT 0,
  score_a integer NOT NULL DEFAULT 0,
  score_r integer NOT NULL DEFAULT 0,
  score_k integer NOT NULL DEFAULT 0,
  learning_target text,                 -- 受測者正在學的語言／東西（自由填寫）
  eeg_used        boolean NOT NULL DEFAULT false,
  source          text NOT NULL DEFAULT 'github-pages'
);
CREATE INDEX IF NOT EXISTS idx_pubvark_created ON public.public_vark_submissions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_pubvark_dominant ON public.public_vark_submissions(dominant);

-- ---------- RLS：任何人可「投稿」，但沒有人能直接讀個別資料列 ----------
ALTER TABLE public.public_vark_submissions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS pubvark_insert_anyone ON public.public_vark_submissions;
CREATE POLICY pubvark_insert_anyone ON public.public_vark_submissions
  FOR INSERT TO anon, authenticated
  WITH CHECK (true);
-- 故意不建 SELECT policy → 前端 anon key 無法讀回任何列（保護隱私）。

-- ---------- 彙總統計 RPC（只回傳統計數字，不回個資） ----------
CREATE OR REPLACE FUNCTION public.public_vark_stats()
RETURNS json
LANGUAGE sql SECURITY DEFINER SET search_path = public
AS $$
  SELECT json_build_object(
    'total', (SELECT count(*) FROM public.public_vark_submissions),
    'last_7d', (SELECT count(*) FROM public.public_vark_submissions
                WHERE created_at >= now() - interval '7 days'),
    'eeg_used', (SELECT count(*) FROM public.public_vark_submissions WHERE eeg_used),
    'by_dominant', (
      SELECT coalesce(json_object_agg(dominant, c), '{}'::json)
      FROM (SELECT dominant, count(*) c FROM public.public_vark_submissions GROUP BY dominant) d
    ),
    'by_target', (
      SELECT coalesce(json_agg(json_build_object('target', target, 'count', c) ORDER BY c DESC), '[]'::json)
      FROM (
        SELECT nullif(lower(trim(learning_target)), '') AS target, count(*) c
        FROM public.public_vark_submissions
        WHERE nullif(lower(trim(learning_target)), '') IS NOT NULL
        GROUP BY 1 ORDER BY c DESC LIMIT 20
      ) t
    ),
    'recent', (
      SELECT coalesce(json_agg(json_build_object(
        'dominant', dominant, 'target', learning_target, 'at', created_at) ORDER BY created_at DESC), '[]'::json)
      FROM (SELECT dominant, learning_target, created_at
            FROM public.public_vark_submissions ORDER BY created_at DESC LIMIT 12) r
    )
  );
$$;

GRANT EXECUTE ON FUNCTION public.public_vark_stats() TO anon, authenticated, service_role;

-- ============================================================
-- 完成。前端（index.html）匿名 POST 進來，admin.html 呼叫 public_vark_stats()。
-- ============================================================
