# Bolt's Performance Journal

This is Bolt's performance journal documenting critical learnings.

## 2026-08-13 - [NFC Passport Passive Authentication (PA) Double Parsing and Slice Allocation Optimization]
**Learning:** In the e-Passport NFC passive authentication flow, parsing data groups (specifically DG1) was performing redundant work (double-parsing the same payload). Additionally, `parseDG1` was previously converting entire byte slices into intermediate string values just to find substring matches, which significantly increased heap memory allocations in critical security verification paths.
**Action:** Parse raw data groups exactly once upfront and cache the result for downstream usage. Use index scanning over the byte slice directly to find the MRZ prefix index first, then extract only the required sub-slices into strings, avoiding wasteful intermediate slice-to-string allocations.
