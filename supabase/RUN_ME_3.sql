-- ============================================================
-- MemoLingua · 訓練內容後端化 + 模擬資料
-- ① exercises 表：22 張卡的設定（名稱/形式/分鐘/描述）→ 後台可編輯
-- ② exercise_content 表：各卡的題庫 → 後台可增刪題目
-- ③ 模擬資料：120 位假使用者的 VARK / 八大天賦 / 訓練行為
-- 用法：Supabase → SQL Editor → 貼上全部 → Run（可重複執行）
-- 前提：已跑過 RUN_ME.sql（要 is_admin()）與 RUN_ME_2.sql（要 play_events）
-- ============================================================

-- ========== ① 訓練卡設定 ==========
CREATE TABLE IF NOT EXISTS public.exercises (
  id          text PRIMARY KEY,              -- 對應 play.html 的卡片 id
  name        text NOT NULL,
  icon        text,
  mode        text NOT NULL,                 -- ai/card/game/sound/similar/tool
  minutes     int  NOT NULL DEFAULT 6,
  description text,
  is_active   boolean NOT NULL DEFAULT true,
  sort        int NOT NULL DEFAULT 100,
  updated_at  timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.exercises ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS ex_read_all ON public.exercises;
CREATE POLICY ex_read_all ON public.exercises FOR SELECT USING (true);   -- 前端要讀來顯示
DROP POLICY IF EXISTS ex_write_admin ON public.exercises;
CREATE POLICY ex_write_admin ON public.exercises FOR ALL TO authenticated
  USING (public.is_admin()) WITH CHECK (public.is_admin());             -- 只有管理員能改

-- ========== ② 題庫 ==========
-- payload 用 jsonb，因為每種卡的題目結構不同（字根卡 vs 辨音對 vs 因果鏈）
CREATE TABLE IF NOT EXISTS public.exercise_content (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  exercise_id text NOT NULL REFERENCES public.exercises(id) ON DELETE CASCADE,
  payload     jsonb NOT NULL,
  is_active   boolean NOT NULL DEFAULT true,
  sort        int NOT NULL DEFAULT 100,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_content_ex ON public.exercise_content(exercise_id) WHERE is_active;
ALTER TABLE public.exercise_content ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS con_read_all ON public.exercise_content;
CREATE POLICY con_read_all ON public.exercise_content FOR SELECT USING (true);
DROP POLICY IF EXISTS con_write_admin ON public.exercise_content;
CREATE POLICY con_write_admin ON public.exercise_content FOR ALL TO authenticated
  USING (public.is_admin()) WITH CHECK (public.is_admin());

-- ========== 22 張卡 + 4 個新小遊戲 ==========
INSERT INTO public.exercises (id,name,icon,mode,minutes,description,sort) VALUES
 ('hook','情境鉤子卡','📍','ai',7,'AI 把單字藏進情境台詞，回頭考你記不記得',10),
 ('story','情感故事卡','📖','ai',8,'把 5 個單字編進有情緒轉折的故事',20),
 ('feynman','費曼原理卡','🧑‍🏫','ai',9,'你教 AI，AI 連環追問「為什麼」',30),
 ('impromptu','即時輸出卡','⚡','ai',5,'不給準備時間的即興任務',40),
 ('podcast','Podcast 說書人任務','🎙️','ai',8,'60 秒把知識講給聽眾聽',50),
 ('meme','諧音迷因與口訣創作家','😂','ai',6,'把考點編成順口溜',60),
 ('rp','情境式 AI 劇本殺','🎭','ai',9,'用對詞才解鎖下一段劇情',70),
 ('bug','AI 挑錯與除錯專家任務','🐛','ai',8,'抓出 AI 故意寫錯的地方',80),
 ('fixloop','錯誤修正回路','🔁','ai',5,'先自己診斷錯因，再重做一次',90),
 ('root','字根字首拆解樹','🧩','card',7,'前綴+字根+字尾拼出真實單字',100),
 ('web','概念織網卡','🕸️','card',7,'用類比連結跨域概念',110),
 ('imgremix','AI 圖像生成變形記','🎨','card',7,'AI 生成荒謬畫面當記憶錨點',120),
 ('chain','知識地圖連連看','🗺️','card',9,'排出因為A所以B的因果鏈',130),
 ('numcode','數字轉碼訓練','🔢','card',6,'0-9 圖像表 → 編故事 → 蓋牌回想',140),
 ('gesture','微動作記憶法指南','🤚','game',5,'3 秒內選出對應手勢',150),
 ('palace','記憶宮殿 3D 線上版','🏛️','game',8,'把知識放進房間，走一遍取回',160),
 ('minimal','聲音跟讀卡','🎧','sound',6,'辨音 + 跟讀',170),
 ('rap','Rap 節奏單字覆誦','🎤','sound',5,'配節拍器念音節',180),
 ('twin','相似概念拆解','👯','similar',7,'易混淆概念的差異拆解',190),
 ('table','資料轉表格訓練','📊','tool',8,'把打亂資料整理成表格',200),
 ('highlight','螢光色階與符號筆記術','🖍️','tool',6,'3 色原則把課文變藏寶圖',210),
 ('pomodoro','番茄鐘走讀與空間轉換術','🍅','tool',6,'讀20分走5分，換房間角落',220),
 -- 新增的四個固定小遊戲
 ('flip','記憶翻牌配對','🃏','game',6,'翻牌配對：單字 ↔ 中文，翻錯重來',230),
 ('speed','限時快答','⚡','game',4,'單字快閃，限時選正確中譯，有連擊',240),
 ('nback','N-Back 工作記憶','🧠','game',5,'字母序列，判斷是否與 N 步前相同',250),
 ('jigsaw','句子拼圖','🧩','game',6,'把打散的單字拖成正確語序',260)
ON CONFLICT (id) DO UPDATE SET
  name=EXCLUDED.name, icon=EXCLUDED.icon, mode=EXCLUDED.mode,
  minutes=EXCLUDED.minutes, description=EXCLUDED.description,
  sort=EXCLUDED.sort, updated_at=now();

-- ========== 題庫種子（可在後台繼續新增） ==========
DELETE FROM public.exercise_content WHERE exercise_id IN ('flip','speed','nback','jigsaw','twin','minimal','chain','root');

-- 翻牌配對：單字 ↔ 中文
INSERT INTO public.exercise_content (exercise_id,payload,sort) VALUES
 ('flip','{"en":"accomplish","zh":"完成、達成"}',1),
 ('flip','{"en":"reluctant","zh":"不情願的"}',2),
 ('flip','{"en":"ambiguous","zh":"模稜兩可的"}',3),
 ('flip','{"en":"persistent","zh":"堅持不懈的"}',4),
 ('flip','{"en":"overwhelmed","zh":"不知所措的"}',5),
 ('flip','{"en":"resourceful","zh":"機智的"}',6);

-- 限時快答：單字 + 正解 + 三個干擾選項
INSERT INTO public.exercise_content (exercise_id,payload,sort) VALUES
 ('speed','{"w":"abandon","a":"放棄","d":["採用","讚美","延長"]}',1),
 ('speed','{"w":"benefit","a":"好處","d":["缺點","懲罰","障礙"]}',2),
 ('speed','{"w":"crucial","a":"關鍵的","d":["次要的","隨機的","模糊的"]}',3),
 ('speed','{"w":"decline","a":"下降、婉拒","d":["上升","接受","擴張"]}',4),
 ('speed','{"w":"enhance","a":"增強","d":["削弱","忽略","隱藏"]}',5),
 ('speed','{"w":"fragile","a":"脆弱的","d":["堅固的","巨大的","昂貴的"]}',6),
 ('speed','{"w":"generous","a":"慷慨的","d":["吝嗇的","嚴厲的","害羞的"]}',7),
 ('speed','{"w":"hesitate","a":"猶豫","d":["衝刺","確定","忘記"]}',8);

-- 句子拼圖：正確語序的句子（前端會打散）
INSERT INTO public.exercise_content (exercise_id,payload,sort) VALUES
 ('jigsaw','{"s":"I have been studying English for three years","hint":"現在完成進行式"}',1),
 ('jigsaw','{"s":"She would have called you if she had known","hint":"混合條件句"}',2),
 ('jigsaw','{"s":"The book that I borrowed was really interesting","hint":"關係子句"}',3),
 ('jigsaw','{"s":"Not only did he apologize but he also paid","hint":"倒裝句"}',4),
 ('jigsaw','{"s":"There is nothing more important than your health","hint":"比較級"}',5);

-- N-Back 用的字母池
INSERT INTO public.exercise_content (exercise_id,payload,sort) VALUES
 ('nback','{"letters":["A","B","C","D","E","F","G","H"],"n":2,"rounds":20}',1);

-- 辨音對
INSERT INTO public.exercise_content (exercise_id,payload,sort) VALUES
 ('minimal','{"a":"ship","b":"sheep"}',1),('minimal','{"a":"led","b":"lead"}',2),
 ('minimal','{"a":"bit","b":"beat"}',3),('minimal','{"a":"full","b":"fool"}',4),
 ('minimal','{"a":"live","b":"leave"}',5),('minimal','{"a":"sit","b":"seat"}',6);

-- 雙胞胎卡
INSERT INTO public.exercise_content (exercise_id,payload,sort) VALUES
 ('twin','{"a":"affect","b":"effect","h":"affect 是動詞（影響），effect 通常是名詞（結果）。","m":"💡 Actions AFFECT, Effects are the End result"}',1),
 ('twin','{"a":"its","b":"it''s","h":"its 是所有格，it''s 是 it is 的縮寫。","m":"💡 有撇號的一律是縮寫，所有格從不用撇號"}',2),
 ('twin','{"a":"then","b":"than","h":"then 表時間順序，than 用於比較。","m":"💡 thAn 有 a，用在比較(compAre)"}',3),
 ('twin','{"a":"lose","b":"loose","h":"lose 動詞（失去），loose 形容詞（鬆的）。","m":"💡 loose 多一個 o，像鬆開多一圈"}',4),
 ('twin','{"a":"principal","b":"principle","h":"principal 校長／主要的，principle 原則。","m":"💡 The principAL is your PAL；principLE 是 ruLE"}',5);

-- 因果鏈
INSERT INTO public.exercise_content (exercise_id,payload,sort) VALUES
 ('chain','{"t":"工業革命的因果鏈","items":["蒸汽機發明","工廠大量生產","農村人口湧入城市","都市化與勞工階級形成"]}',1),
 ('chain','{"t":"溫室效應的因果鏈","items":["燃燒化石燃料","大氣中二氧化碳增加","紅外線輻射被吸收","全球平均氣溫上升"]}',2),
 ('chain','{"t":"供需失衡的因果鏈","items":["原物料短缺","生產成本上升","商品售價提高","消費者需求下降"]}',3);

-- 字根卡
INSERT INTO public.exercise_content (exercise_id,payload,sort) VALUES
 ('root','{"w":"predict","m":"預測（pre 事先 + dict 說）"}',1),
 ('root','{"w":"prediction","m":"預測（名詞）"}',2),
 ('root','{"w":"predictable","m":"可預測的"}',3),
 ('root','{"w":"report","m":"報告（re 再次 + port 帶）"}',4),
 ('root','{"w":"respect","m":"尊重（re 再 + spect 看）"}',5),
 ('root','{"w":"portable","m":"可攜帶的（port 帶 + able）"}',6),
 ('root','{"w":"dictation","m":"聽寫（dict 說 + ation）"}',7);

-- ========== 讀題庫的 RPC（前端用；只回 active 的） ==========
CREATE OR REPLACE FUNCTION public.get_content(p_exercise text)
RETURNS TABLE(payload jsonb)
LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT c.payload FROM public.exercise_content c
  JOIN public.exercises e ON e.id=c.exercise_id
  WHERE c.exercise_id=p_exercise AND c.is_active AND e.is_active
  ORDER BY c.sort, c.created_at;
$$;
GRANT EXECUTE ON FUNCTION public.get_content(text) TO anon, authenticated, service_role;

-- ========== ③ 模擬資料：120 位假使用者 ==========
-- 全部標記 source='demo'，之後要清掉只要 DELETE ... WHERE source='demo'
-- 注意：play_stats/memory_scale_public_count 只過濾 selftest%，所以 demo 資料
-- 會出現在後台（這正是我們要的——讓你看到報告長什麼樣）。
DELETE FROM public.memory_scale_submissions WHERE source='demo';
DELETE FROM public.play_events WHERE source='demo';
DELETE FROM public.public_vark_submissions WHERE source='demo';

-- 八大天賦量表：120 筆，天賦分布刻意不平均（比較像真實世界）
INSERT INTO public.memory_scale_submissions (created_at,top1,top2,scores,in_v,in_a,in_t,in_act,learning_target,genius,source)
SELECT
  now() - (random()*30||' days')::interval - (random()*24||' hours')::interval,
  t.top1, t.top2,
  jsonb_build_object('img',(random()*5)::int,'snd',(random()*5)::int,'txt',(random()*5)::int,'act',(random()*5)::int,
                     'soc',(random()*5)::int,'sys',(random()*5)::int,'cre',(random()*5)::int,'biz',(random()*5)::int),
  round((0.2+random()*0.7)::numeric,3), round((0.2+random()*0.7)::numeric,3),
  round((0.2+random()*0.7)::numeric,3), round((0.2+random()*0.7)::numeric,3),
  (ARRAY['英文','多益 TOEIC','日文','雅思 IELTS','英文會話','數學','物理','韓文','程式設計','英檢中高級'])[1+floor(random()*10)],
  t.genius, 'demo'
FROM (
  SELECT
    (ARRAY['img','snd','txt','act','soc','sys','cre','biz'])[w] AS top1,
    (ARRAY['img','snd','txt','act','soc','sys','cre','biz'])[1+floor(random()*8)::int] AS top2,
    (ARRAY['visionary','melodist','architect','explorer','performer','analyst','narrator','connector'])[w] AS genius
  FROM (
    -- 用加權讓分布不平均：img/act 較多，biz/sys 較少
    SELECT (ARRAY[1,1,1,1,2,2,2,3,3,3,4,4,4,4,5,5,6,6,7,7,8])[1+floor(random()*21)::int] AS w
    FROM generate_series(1,120)
  ) s
) t;

-- 簡易 VARK：60 筆
INSERT INTO public.public_vark_submissions (created_at,dominant,secondary,score_v,score_a,score_r,score_k,learning_target,eeg_used,source)
SELECT
  now() - (random()*30||' days')::interval,
  d, (ARRAY['visual','auditory','reading','kinesthetic'])[1+floor(random()*4)::int],
  (random()*6)::int,(random()*6)::int,(random()*6)::int,(random()*6)::int,
  (ARRAY['英文','多益','日文','英文會話',NULL])[1+floor(random()*5)],
  random()<0.25, 'demo'
FROM (
  SELECT (ARRAY['visual','visual','visual','auditory','auditory','reading','kinesthetic','kinesthetic'])[1+floor(random()*8)::int] AS d
  FROM generate_series(1,60)
) x;

-- 訓練行為：約 700 筆事件（有人開了沒完成，符合真實漏斗）
INSERT INTO public.play_events (created_at,exercise_id,mode,talent,event,score_v,score_t,source)
SELECT
  ts,
  ex, md, tl,
  CASE WHEN random()<0.62 THEN 'complete' ELSE 'open' END AS ev,
  CASE WHEN md='game' AND random()<0.62 THEN sc ELSE NULL END,
  CASE WHEN md='game' AND random()<0.62 THEN sc||'/8' ELSE NULL END,
  'demo'
FROM (
  SELECT
    now() - (random()*30||' days')::interval - (random()*24||' hours')::interval AS ts,
    e.id AS ex, e.mode AS md,
    (ARRAY['img','snd','txt','act','soc','sys','cre','biz',NULL])[1+floor(random()*9)::int] AS tl,
    (3+random()*5)::int AS sc
  FROM public.exercises e
  -- 熱門卡被抽中機率高：依 sort 反向加權，讓分布有高有低
  CROSS JOIN generate_series(1, 1 + floor(random()*55)::int) g
  WHERE e.is_active
) q;

-- ========== 驗證 ==========
SELECT
  (SELECT count(*) FROM public.exercises)                                   AS 訓練卡數,
  (SELECT count(*) FROM public.exercise_content)                            AS 題庫筆數,
  (SELECT count(*) FROM public.memory_scale_submissions WHERE source='demo') AS 模擬天賦量表,
  (SELECT count(*) FROM public.public_vark_submissions WHERE source='demo')  AS 模擬VARK,
  (SELECT count(*) FROM public.play_events WHERE source='demo')              AS 模擬訓練事件;
