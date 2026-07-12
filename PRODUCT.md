# Product

## Register

product

## Platform

adaptive

## Users

Foreign tourists in Thailand who want to pay Thai merchants via PromptPay QR, funding the payment from a foreign payment method (credit card, Apple Pay, or stablecoin) rather than a Thai bank account. They are on their phone, often outdoors, mid-transaction at a counter with a merchant waiting — low patience for friction, high need for clarity on exchange rate, fees, and payment status. Job to be done: scan a Thai QR, confirm exactly what they're paying (in their currency and THB), and get a fast, unambiguous confirmation the merchant got paid.

## Product Purpose

Paycif is a cross-border payment orchestration app: tourist funds in → USDC via a licensed on-ramp partner → licensed off-ramp partner converts to THB → PromptPay to the merchant. Paycif itself holds no payment license and never touches or controls funds directly; it orchestrates licensed partners. Success = a tourist trusts the app enough to complete a payment in under the time a card terminal would take, with total confidence the merchant received the right amount.

## Brand Personality

Trustworthy fintech — Wise/Revolut register, not a Thai bank app and not a crypto/DeFi app. Precise, calm, numerate. The interface should read as "a fintech that happens to move value through stablecoin," never as "a crypto app you pay with." Financial figures get the visual weight; chrome stays quiet.

## Anti-references

- Traditional Thai bank apps (dated, government-form-like, cluttered)
- Crypto/DeFi apps (neon gradients, glassmorphism-as-default, wallet-address-forward UI)
- No specific named anti-reference beyond category avoidance — judgment deferred to design taste within the Wise/Revolut lane

## Design Principles

1. **Numbers are the hero.** Amount, FX rate, and fee are the most-looked-at elements on any screen; give them the visual weight (per prior design.md's tabular-numeral + weight treatment), keep everything else quiet.
2. **Never imply custody.** Paycif orchestrates; it does not hold funds. No UI language or visual metaphor (progress bars implying "your money is here," wallet icons implying Paycif-controlled balance) should suggest Paycif itself holds or moves money — see [CLAUDE.md](CLAUDE.md) §5.
3. **Outdoor-first legibility.** Users are frequently outdoors mid-transaction, on a phone screen, in direct sunlight — contrast and touch-target size are not optional polish, they're the primary use condition.
4. **Optimistic speed over literal accuracy.** Mask 3-5s partner-API latency (on-ramp auth, off-ramp settlement) with immediate, honest visual feedback rather than a spinner-and-silence wait.
5. **Merchant-zero.** The merchant-facing side of any flow must work with unmodified existing PromptPay QR infrastructure — the tourist app should never require the merchant to do anything different.

## Accessibility & Inclusion

No formal WCAG level specified by the team; treat WCAG 2.1 AA as the working baseline (4.5:1 body text contrast, visible focus states, `prefers-reduced-motion` respected) given this is a financial app. Multi-language support (English UI + Thai merchant-name rendering) is a hard requirement, not a nice-to-have — confirmed by the existing `l10n` setup in the Flutter app.
