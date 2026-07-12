# 歸檔 SQL（勿再執行）

這些檔案已被上層的整併檔取代，僅留作歷史紀錄：

- `admin_lockdown.sql`、`memory_scale_collector.sql`、`memory_scale_export.sql`、
  `scale_add_genius.sql`、`scale_leads.sql` → 全部整併進 **`../RUN_ME.sql`**
- `schema.sql` → 這是舊 fluent-ai 的社交功能 schema（energy/friends/shop），
  與 MemoLingua 無關；MemoLingua 用的是 **`../memolingua_schema.sql`**

## 現行要跑的只有三個（依序）：
1. `../memolingua_schema.sql` （已跑過 ✅）
2. `../seed_vark_questions.sql`（已跑過 ✅）
3. `../RUN_ME.sql` （待跑：genius 欄位 + 後台上鎖 + 管理員）
