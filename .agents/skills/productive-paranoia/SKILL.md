---
name: productive-paranoia
description: Enforce "Productive Paranoia" and "Asymmetric Risk" mindsets in all coding and architectural decisions. ACTIVATE this skill whenever writing, reviewing, or refactoring code for the Paycif application.
---

# Productive Paranoia & Asymmetric Risk Guidelines

For all sessions, conversations, and code modifications within the Paycif project, you MUST adopt the philosophies of **Productive Paranoia** and **Asymmetric Risk**. 

As a fintech application, bugs do not just cause frustration—they cause financial damage and destroy user trust. 

## 1. Productive Paranoia (Expect the Worst)
Always assume the environment is hostile and unstable. When writing or reviewing code, actively ask yourself:
*   **"What if the network drops right here?"** (Implement local caching, offline fallbacks, and retry mechanisms).
*   **"What if the user mashes this button 10 times in a second?"** (Implement debouncing, `_isProcessing` locks, or `AbsorbPointer`).
*   **"What if the OS kills the app or the user backgrounds it during this process?"** (Use AppLifecycleListeners, save state aggressively).
*   **"What if an attacker is trying to dump memory or hook this function?"** (Clear sensitive arrays from memory immediately, avoid stringifying secrets).

**Rule:** Your code must never crash or freeze. It must always "Degrade Gracefully" and provide clear, transparent feedback to the user.

## 2. Asymmetric Risk (Massive Upside, Zero Downside)
Always look for architectural decisions that cost very little to implement but prevent catastrophic failures.
*   **Defensive Programming:** Add explicit assertions, null checks, and boundary limits even if you think "this should never happen." The cost of an `if (mounted)` check is zero; the cost of a crash is lost trust.
*   **Zero-Trust State:** Do not trust local booleans for critical authentication. Prepare the frontend to handle cryptographic nonces and server-side validation.
*   **Idempotency:** For any financial transaction or API call, assume it might be sent twice.

## Instructions for the Agent:
- When the user asks you to implement a feature, **automatically include paranoid edge-case handling** without waiting to be asked.
- If you spot a vulnerability or a potential race condition in existing code during a routine task, point it out immediately and propose a fix.
- Do not build "Happy Path Only" logic. Every feature must have its error path built first.
