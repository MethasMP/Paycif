# CLAUDE.md — Paycif

> Context engineering file for AI coding agents.
> Loaded automatically into context at session start. Keep this file **signal-dense, not exhaustive**.
> Last updated: 2026-05-29

---

## Project Identity

**Paycif** — a mobile payment platform enabling foreign tourists in Thailand to pay Thai merchants via PromptPay QR codes, bridging international fiat rails with Thailand's domestic payment infrastructure through stablecoin (USDC) as the settlement bridge.

| Field | Value |
|---|---|
| Legal entity | PAYSIF COMPANY LIMITED |
| Registration | 0255569000991 (registered 27 March 2026) |
| Founder | นาย เมธัส ภาคภูมิพงศ์ (Methas Pakphumipong) |
| Contact | Methaspak@gmail.com · 096-9240925 |
| Business email | hello@paysif.io |
| Domain | paysif.io |
| Stage | Pre-launch — technical implementation phase |

---

## Architecture Overview

Paycif acts as an orchestrator between licensed third-party partners. **We do not hold a payment license ourselves** — all regulated activity is handled by licensed partners. The architecture must be designed so any partner can be swapped with minimal code change (abstraction layer over all partner APIs).

```
┌─────────────────────────────────────────────────────┐
│                    TOURIST                          │
│  Pays via whatever method the on-ramp partner       │
│  supports: card, Apple Pay, bank transfer, etc.     │
│  (available methods vary by partner and country)    │
└────────────────────┬────────────────────────────────┘
                     │ Fiat
                     ▼
┌─────────────────────────────────────────────────────┐
│              ON-RAMP PARTNER                        │
│  Role: Licensed crypto on-ramp provider             │
│  Action: Fiat → USDC                                │
│  Examples of this role: Ramp Network, Alchemy Pay,  │
│  Coinflow, MoonPay, Transak (pay-per-use, no        │
│  exclusivity — provider can be swapped)             │
└────────────────────┬────────────────────────────────┘
                     │ USDC (Base network)
                     ▼
┌─────────────────────────────────────────────────────┐
│           PAYCIF POOL WALLET                        │
│  Role: USDC custody bridge between on-ramp and      │
│  off-ramp (non-custodial smart contract wallet      │
│  on Base network, EVM L2)                           │
│  Managed by: Wallet infrastructure partner          │
│  (e.g., a smart account / wallet SDK provider)      │
└────────────────────┬────────────────────────────────┘
                     │ USDC
                     ▼
┌─────────────────────────────────────────────────────┐
│              OFF-RAMP PARTNER                       │
│  Role: Licensed crypto off-ramp + fiat settlement   │
│  Action: USDC → THB, disbursed via PromptPay QR     │
│  Must hold Thai payment license (or work with a     │
│  licensed Thai payment gateway for the final leg)   │
│  Examples of this role: Ramp Network, TransFi,      │
│  Alchemy Pay (same or different provider as on-ramp)│
└────────────────────┬────────────────────────────────┘
                     │ THB via PromptPay
                     ▼
┌─────────────────────────────────────────────────────┐
│              THAI MERCHANT                          │
│  Receives payment via PromptPay QR (merchant QR,   │
│  rate: 0.90% + $0.04 — BOT regulated floor)        │
└─────────────────────────────────────────────────────┘
```

### Key Design Principle: Partner Abstraction

On-ramp and off-ramp may be the same company or different companies. **The codebase must never be tightly coupled to a specific provider.** All partner integrations sit behind an interface/adapter layer:

```
IOnRampProvider  { initiateTopUp(), getStatus(), getWebhookPayload() }
IOffRampProvider { initiatePayout(), getStatus(), getWebhookPayload() }
IWalletProvider  { getBalance(), transfer(), getAddress() }
```

Swapping a provider = swapping the adapter, not rewriting business logic.

---

## Revenue Model

| Source | Detail |
|---|---|
| FX spread on tourist top-up | 2.5% spread → ~฿8–18 net per ฿2,000 transaction |
| Launch scope | Merchant QR only |
| Personal PromptPay QR | Deferred — BOT regulatory floor, not negotiable |
| Merchant QR rate | 0.90% + $0.04 (BOT floor) |

---

## Tech Stack

| Layer | Technology |
|---|---|
| Mobile app | Flutter (iOS + Android) |
| Design system | Teal + Gold — primary `#0F6E56`, CTA `#EF9F27` |
| Settlement token | USDC on Base network (EVM-compatible L2) |
| Wallet layer | Smart account / wallet SDK (provider-agnostic interface) |
| On-ramp layer | Licensed on-ramp partner (adapter pattern, swappable) |
| Off-ramp layer | Licensed off-ramp + PromptPay partner (adapter pattern, swappable) |
| Business bank | SCB |
| Target market | Foreign tourists from NFC-dominant markets (Europe, US, Japan) |

---

## Agent Workflow

This project is built via **vibe-coding**: founder directs AI agents, agents write code. Follow this loop strictly:

```
gather context → take action → verify work → repeat
```

1. **Gather context** — read `CLAUDE.md` (this file), then `NOTES.md`. Load source files just-in-time via search/grep. Never load entire large files into context.
2. **Take action** — write code, create files, run scripts.
3. **Verify** — lint, type-check, run tests before declaring done. Never say "done" without running verification.
4. **Persist** — update `NOTES.md` with decisions made. Update `TODO.md` after each action.

---

## Directory Structure

```
paycif/
├── CLAUDE.md                    ← this file (loaded upfront, do not modify unless asked)
├── NOTES.md                     ← agent working memory (read/write freely each session)
├── TODO.md                      ← task list (update as you work)
├── docs/
│   ├── architecture.md          ← detailed payment flow diagrams
│   ├── compliance.md            ← BOT / KYC / AML / licensing notes
│   └── integrations/            ← per-partner integration notes (load just-in-time)
│       ├── onramp-adapter.md
│       ├── offramp-adapter.md
│       └── wallet-adapter.md
├── app/                         ← Flutter mobile app
│   ├── lib/
│   └── test/
└── backend/                     ← API / webhook / settlement logic
    ├── src/
    │   ├── adapters/            ← one folder per partner, behind shared interface
    │   └── core/                ← business logic, never import adapters directly
    └── test/
```

---

## Behavior Rules

### DO

- Write **production-quality code** — this is a fintech app handling real money.
- Follow **PCI-DSS awareness**: never log card numbers, CVVs, or raw PANs anywhere.
- Design every partner integration behind an **interface/adapter** — business logic must not depend on a specific provider.
- Keep `NOTES.md` updated with decisions, blockers, and context that would be lost across sessions.
- Update `TODO.md` after each action (check off done items, add discovered sub-tasks).
- For payment flows, **write the test first** (TDD), then implement.
- For any ambiguous requirement, ask **one clarifying question** before proceeding.
- Use **typed / structured output** (JSON with schema) for all inter-service communication.
- Every external API call must have: **timeout + retry + failure path**.

### DO NOT

- Do not hardcode API keys, secrets, or provider credentials anywhere. Use environment variables.
- Do not skip error handling in any payment flow step.
- Do not couple business logic directly to a provider SDK — always go through the adapter interface.
- Do not modify `CLAUDE.md` unless explicitly asked.
- Do not declare a task complete without running the verification step.
- Do not load entire large files (logs, CSVs, DB dumps) into context — use `head`, `tail`, `grep`.

---

## Compliance Context

| Item | Detail |
|---|---|
| Thai payment regulation | BOT regulates PromptPay QR rates and licensing |
| Paycif's position | Orchestrator — regulated activity performed by licensed partners |
| KYC | Tourist KYC handled at app onboarding |
| Arbitration clause | SIAC Singapore (per vendor contracts) |
| Liability cap | 12-month cap (per vendor contracts) |
| Fee change notice | 45-day notice required from partners |

---

## Context Management Notes

- **This file** = upfront context (small, high-signal).
- **`NOTES.md`** = persistent agent memory — read at every session start, write whenever a non-obvious decision is made.
- **Integration docs** = load just-in-time only when working on that specific adapter.
- If context window approaches limit: summarize state → write to `NOTES.md` → compact and continue.
- For deep exploration tasks (e.g., researching a new partner's webhook format): treat as a focused subtask, return only the relevant summary to main context.

---

## Definition of Done

A task is **done** when all of the following are true:

- [ ] Code compiles / passes linter with zero errors
- [ ] Unit tests pass (or new tests written if none existed)
- [ ] No secrets or credentials in code
- [ ] No raw payment data in logs
- [ ] `TODO.md` updated
- [ ] `NOTES.md` updated with any non-obvious decisions made
