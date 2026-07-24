# MemoLingua · 待辦清單（待你決定 / 待你操作）

> 更新：2026-07-19。功能開發都完成了，剩下的都是需要你在外部平台操作、或產品方向決策。

---

## 🔧 待你操作（有明確步驟）

### 1. （選配）RUN_ME_4.sql — 讓 AI 卡題庫進後台可編輯
- **現況**：AI 對話卡（情境鉤子/故事/劇本殺…）的單字池還是用前端內建題庫（能正常玩）。
- **跑了會怎樣**：8 組 AI 卡內容進 `exercise_content`，後台「內容管理」分頁就能改（機構換教材用）。
- **怎麼做**：[SQL Editor](https://supabase.com/dashboard/project/ycgjzrvfzaqaicvdtagq/sql/new) 貼上 `supabase/RUN_ME_4.sql` → Run。
- **不跑也沒差**：前端有 fallback，不影響使用者。

### 2. 上線前：清除模擬 demo 資料
- **現況**：後台有 120 筆假天賦量表 + 60 筆 VARK + ~900 筆訓練事件（`source='demo'`），讓你預覽報告用。
- **真正對外上線前**跑這段清掉（對外計數本來就不含 demo，但後台會看到）：
  ```sql
  DELETE FROM public.memory_scale_submissions WHERE source='demo';
  DELETE FROM public.public_vark_submissions   WHERE source='demo';
  DELETE FROM public.play_events                WHERE source='demo';
  ```

### 3. ④ 登入（Google / Magic Link）— 你設定完我接前端
- **現況**：Email+密碼可用；Google=關閉；Magic Link=未開。
- **Google（推薦，不靠 email）**：
  1. [Google Cloud Console](https://console.cloud.google.com) → Credentials → OAuth client ID（Web）
  2. Authorized redirect URI 填：`https://ycgjzrvfzaqaicvdtagq.supabase.co/auth/v1/callback`
  3. [Supabase Providers](https://supabase.com/dashboard/project/ycgjzrvfzaqaicvdtagq/auth/providers) → Google → Enable + 貼 ID/Secret
- **Magic Link（最簡單但要 SMTP）**：Supabase Providers → Email → 開 Magic Link（＋見第 6 項接 SMTP 才穩）
- **共同**：[URL Configuration](https://supabase.com/dashboard/project/ycgjzrvfzaqaicvdtagq/auth/url-configuration) → Redirect URLs 加 `https://fluentai-nine.vercel.app/**` 和 `https://fluent-ai-mu.vercel.app/**`
- **設定完跟我說**：我把 `GOOGLE_LOGIN_ENABLED` 改 true / 加 Magic Link 按鈕 + 重新部署。

### 6. （選配）自訂 SMTP，讓信穩定送達
- **為什麼**：Supabase 內建寄信每小時 2-4 封、常進垃圾信（你之前踩過）。驗證信、Magic Link、密碼重設都靠它。
- **怎麼做**：[resend.com](https://resend.com) 免費每月 3000 封 → 拿 SMTP 帳密 → Supabase → Authentication → Emails → SMTP Settings 填入。

---

## 🤔 待你決定（產品方向）

### 4. ②③ 訓練典範要不要統一
- **現況**：② fluent-ai 用「依 8 型的 AI 課題（genius-tasks）」，③ play.html 用「26 張卡片遊戲」。**是兩種不同典範，不是重複內容。**
- **要不要合**：合＝大工程（要選一種當標準）。不合＝各自發展（③獲客體驗、②深度學習）。
- 這題要你先想清楚產品定位再動，我可以幫你做決策盤點。

### 5. 主 App 定案
- **已傾向 ②**（功能超集、可上架 App）。① 和 ③ 已加導流橫幅指向 ②。
- 若確定，可考慮：① memolingua 是否只留當備份、還是完全退役。

---

## ✅ 已完成（給你回顧）
- 量表→專屬訓練→複習→課表 完整閉環
- 26 張訓練卡全部真的能玩（含 4 個新小遊戲）
- AI 依天賦教（核心賣點兌現）+ AI 卡完成判定
- 後台三合一（天賦量表/訓練行為/內容管理/VARK）+ 模擬資料
- 訓練內容後端化（題庫後台可編輯）
- 測驗收斂（一個正宮 + 命名對照透明）
- 8 型對照表單一正本 type-map.json（防 drift）
- 三站導流橫幅指向 ②
