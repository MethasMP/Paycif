---
name: feedback-headroom-usage
description: Proactively use headroom_compress on large tool outputs every session without being asked
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 3f5ad221-42c0-4db9-80b5-a352f6903cb1
---

Use `mcp__headroom__headroom_compress` proactively whenever large content (big file reads, long search/grep results, verbose tool outputs) would otherwise bloat the context window — don't wait for the user to ask each time.

**Why:** User explicitly asked for this to apply every session by default, to save context/cost without needing reminders.

**How to apply:** When about to read/paste large content into context (large file contents, long command output, big search results), consider compressing it with `headroom_compress` first if the headroom MCP tools are available in the session. If they're deferred tools, load them via ToolSearch (`select:mcp__headroom__headroom_compress,...`) early when starting work that's likely to involve large outputs. Use `headroom_retrieve` later if full details are needed.

**Concrete thresholds (user-defined 2026-06-15):**
- Compress when content is roughly >2,000 tokens (~150-200 lines / ~8,000 chars) and is reference-only.
- Good candidates: large file reads not being edited immediately, build/test/CI logs, npm/yarn install output, grep/search results with >20-30 matches, large API/JSON responses (e.g. Supabase queries, web fetches), verbose subagent/Explore output.
- Do NOT compress: files about to be edited (need exact content for Edit to match), short error messages/stack traces being actively debugged, or content the user explicitly asked to see directly (e.g. diffs to be committed).
