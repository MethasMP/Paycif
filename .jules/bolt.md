## 2026-09-26 - AlchemyPayAdapter String Formatting Optimization
**Learning:** `fmt.Sprintf` calls for timestamps and simple URL/JSON string construction add unnecessary heap allocations and reflection overhead in on-ramp adapter methods (`GenerateManageURL`, `GetToken`).
**Action:** Replace `fmt.Sprintf` with `strconv.FormatInt(ts, 10)`, `strconv.Quote`, and direct string concatenation (`+`) to eliminate reflection overhead and reduce memory allocations.
