-- ============================================================
-- MemoLingua · C：AI 對話卡題庫搬進後端
-- 把原本寫死在 play.html 的 7 組 AI 卡內容搬進 exercise_content，
-- 後台「內容管理」分頁就能改（機構可換成自己的教材）。
-- 前提：已跑過 RUN_ME_3.sql（要 exercises / exercise_content / get_content）
-- 用法：Supabase → SQL Editor → 貼上全部 → Run（可重複執行）
-- ============================================================

DELETE FROM public.exercise_content WHERE exercise_id IN
  ('hook','story','feynman','impromptu','meme','rp','bug');

-- 情境鉤子卡：要藏進情境的單字
INSERT INTO public.exercise_content (exercise_id,payload,sort) VALUES
 ('hook','{"w":"soothing"}',1),('hook','{"w":"reluctant"}',2),('hook','{"w":"ambiguous"}',3),
 ('hook','{"w":"persistent"}',4),('hook','{"w":"genuine"}',5),('hook','{"w":"overwhelmed"}',6),
 ('hook','{"w":"skeptical"}',7),('hook','{"w":"resourceful"}',8);

-- 情感故事卡：主題 + 要編進去的 5 個單字
INSERT INTO public.exercise_content (exercise_id,payload,sort) VALUES
 ('story','{"theme":"機場趕飛機","words":["panicked","boarding","delayed","luggage","relieved"]}',1),
 ('story','{"theme":"餐廳客訴","words":["refund","undercooked","apologize","manager","compensation"]}',2),
 ('story','{"theme":"面試現場","words":["nervous","qualification","strength","salary","opportunity"]}',3);

-- 費曼原理卡：可教學的主題（Podcast 說書人也共用這組）
INSERT INTO public.exercise_content (exercise_id,payload,sort) VALUES
 ('feynman','{"t":"光合作用"}',1),('feynman','{"t":"複利效果"}',2),('feynman','{"t":"供需法則"}',3),
 ('feynman','{"t":"牛頓第三定律"}',4),('feynman','{"t":"關係子句"}',5),('feynman','{"t":"熵"}',6);

-- 即時輸出卡：即興任務
INSERT INTO public.exercise_content (exercise_id,payload,sort) VALUES
 ('impromptu','{"task":"用今天學的 3 個詞造一個投訴信開頭"}',1),
 ('impromptu','{"task":"30 秒解釋一個公式給小學生聽"}',2),
 ('impromptu','{"task":"用 refund 抱怨一個爛商品"}',3),
 ('impromptu','{"task":"描述你昨天做的一件事，全程用過去式"}',4);

-- 諧音迷因：要記的考點
INSERT INTO public.exercise_content (exercise_id,payload,sort) VALUES
 ('meme','{"item":"維也納會議 1815 年"}',1),('meme','{"item":"法國大革命 1789 年"}',2),
 ('meme','{"item":"光合作用的三步驟"}',3),('meme','{"item":"水的沸點 100°C"}',4);

-- 情境式劇本殺：角色 + 5 個核心詞
INSERT INTO public.exercise_content (exercise_id,payload,sort) VALUES
 ('rp','{"role":"回到 1929 年的時空偵探","words":["crash","panic","invest","recover","warn"]}',1),
 ('rp','{"role":"跟外國客戶談判的 PM","words":["deadline","budget","compromise","deliver","risk"]}',2);

-- AI 挑錯：故意寫錯的知識摘要
INSERT INTO public.exercise_content (exercise_id,payload,sort) VALUES
 ('bug','{"text":"二次大戰爆發於 1945 年，起因是珍珠港事變。"}',1),
 ('bug','{"text":"光合作用發生在粒線體，把氧氣轉換成二氧化碳。"}',2),
 ('bug','{"text":"複利的意思是每年拿到一樣多的固定利息。"}',3);

-- 驗證
SELECT exercise_id, count(*) AS 題數
FROM public.exercise_content
WHERE exercise_id IN ('hook','story','feynman','impromptu','meme','rp','bug')
GROUP BY exercise_id ORDER BY exercise_id;
