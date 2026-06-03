## 2025-05-22 - [CI Compatibility] Supabase Realtime Migration
**Learning:** Using `ALTER TABLE ... SET (realtime = true)` in migrations can cause CI failures (`unrecognized parameter "realtime"`) depending on the Postgres version or Supabase CLI environment used.
**Action:** Always enable realtime by adding tables to the `supabase_realtime` publication instead of using the `SET` parameter.
