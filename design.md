<!-- SEED: re-run /impeccable document once the new visual system has real code (theme, components) to capture actual tokens. This file replaces the prior design.md and design-system/paycif/MASTER.md, both of which are retired as of this seed — do not merge values from them. -->

---
name: Paycif
description: Cross-border PromptPay payment orchestration for tourists — trustworthy fintech, not a crypto app.
colors:
  navy-primary: "[to be resolved during implementation]"
  neutral-bg: "[to be resolved during implementation]"
  neutral-surface: "[to be resolved during implementation]"
  ink: "[to be resolved during implementation]"
typography:
  display:
    fontFamily: "[technical/geometric single sans — font to be chosen at implementation]"
  body:
    fontFamily: "[same family as display]"
---

# Design System: Paycif

## 1. Overview

**Creative North Star: "The Quiet Exchange Counter"**

Paycif's interface should feel like Wise or Revolut handed a tourist their receipt at a Thai counter — calm, numerate, and unmistakably not a crypto wallet. The stablecoin leg of the payment (on-ramp → USDC → off-ramp → PromptPay, per [PRODUCT.md](PRODUCT.md)) is infrastructure, not identity; nothing on screen should read as "crypto app," and nothing should imply Paycif itself holds or moves the user's money (Paycif orchestrates licensed partners only — see [CLAUDE.md](CLAUDE.md) §5). Apple Pay / Apple Wallet is the secondary reference for restraint and material honesty: flat, high-contrast, no unnecessary chrome.

This system explicitly rejects: Thai government-form-style banking UI (dense, dated, low contrast), and crypto/DeFi visual language (neon gradients, glassmorphism-as-default, wallet-address-forward layouts, gradient text).

**Key Characteristics:**
- Tinted neutral canvas, one navy accent used sparingly (≤10% of any screen)
- Single geometric/technical sans across the whole type scale, no serif, no display font swap
- Flat by default; elevation only appears as a direct response to interaction
- Restrained motion — transitions mark state changes, nothing choreographed or decorative
- Financial figures (amount, FX rate, fee) carry more visual weight than any other element on screen

## 2. Colors

Restrained strategy: a cool, barely-tinted neutral scale carries the canvas; a single deep navy accent is reserved for primary actions, focus states, and financial emphasis. No secondary or tertiary color role — this is deliberately a two-role palette (Primary + Neutral), not a fabricated three-color system.

### Primary
- **Deep Navy** (`[to be resolved during implementation]`, anchor family: deep blue/navy in the Wise/Revolut register): primary buttons, active nav state, focus rings, links. Reserved — should not appear as a background fill of more than one region per screen.

### Neutral
- **Canvas** (`[to be resolved during implementation]`, near-white with a cool tint, not warm/cream): app background.
- **Surface** (`[to be resolved during implementation]`): cards, sheets, elevated containers — one step off canvas, not a hard white-on-grey jump.
- **Ink** (`[to be resolved during implementation]`): primary text. Must hit ≥4.5:1 against Canvas and Surface — do not default to a light/muted gray for body copy.
- **Muted ink** (`[to be resolved during implementation]`): secondary/metadata text only, still ≥4.5:1 against its background.
- **Border** (`[to be resolved during implementation]`): dividers, input strokes, card edges.

### Named Rules
**The One Accent Rule.** Navy appears on ≤10% of any given screen's surface area. Its rarity is what makes it read as an action, not decoration.
**The No-Custody-Color Rule.** No color or fill is used in a way that implies a live balance or held funds belonging to Paycif — see [PRODUCT.md](PRODUCT.md) principle 2. Balances and rates are always framed as pass-through information, never as "your money sitting here."

## 3. Typography

**Display Font:** [single geometric/technical sans, family to be chosen at implementation — e.g. Inter or IBM Plex Sans family; no serif]
**Body Font:** same family as Display — one typeface across the whole hierarchy, weight does the differentiating work.

**Character:** Precise and unshowy. No font pairing, no personality font for headlines — the numbers and layout carry the "premium" feeling, not a display typeface.

### Hierarchy
- **Display** (Bold/700, large, tight line-height, tabular numerals enabled): payment amount and FX rate only — the single most-looked-at element on any screen.
- **Headline** (SemiBold/600): screen titles, receipt totals.
- **Title** (Medium/500): section headers, card titles.
- **Body** (Regular/400, 16px minimum): primary reading text, 65–75ch max where prose appears.
- **Label** (Medium/500, small, slight positive letter-spacing): form labels, metadata, captions.

### Named Rules
**The Numbers-Are-the-Hero Rule.** Amount, FX rate, and fee always get more weight (via size/weight, never via color-as-decoration) than any surrounding chrome or copy.

## 4. Elevation

Flat by default — the Apple Pay / Apple Wallet reference means depth is conveyed through spacing and the Canvas/Surface tonal step, not drop shadows. Shadows exist only as a direct response to interaction state (a card lifting on press, a sheet appearing over content), never as ambient decoration on static elements.

### Shadow Vocabulary
- **Interaction-lift** (`[value to be resolved at implementation, subtle: short blur radius, low opacity]`): applied only on press/active states for tappable cards.
- **Sheet-overlay** (`[value to be resolved at implementation]`): modal sheets and dialogs only.

### Named Rules
**The Flat-at-Rest Rule.** No card, button, or container carries a shadow while idle. Shadows appear only as a direct response to touch.

## 5. Components

### Buttons
- **Shape:** rounded corners, moderate radius (not full-pill, not sharp-square) — to be fixed at implementation, consistent across all button sizes.
- **Primary:** Navy fill, white text, Bold label, generous horizontal padding, ≥48dp touch target (outdoor/one-handed use per [PRODUCT.md](PRODUCT.md)).
- **Secondary/Ghost:** Ink-colored outline or text-only, no fill — reserved for lower-emphasis actions (cancel, back).
- **Hover/Focus:** state changes via opacity/border shift and a visible focus ring in Navy, transition duration short (restrained motion) — no scale/bounce.

### Cards / Containers
- **Corner Style:** same radius family as buttons, consistent scale.
- **Background:** Surface tone, not pure white-on-white with canvas.
- **Shadow Strategy:** flat at rest; Interaction-lift shadow only when the card is tappable and pressed.
- **Border:** thin Border-token hairline where cards sit directly on Canvas without a shadow to separate them.
- **Internal Padding:** generous — this is a payment app read outdoors, not a dense data table.

### Inputs / Fields
- **Style:** Border-token stroke, Surface background, same radius family.
- **Focus:** Navy border shift + visible focus ring, no glow/blur effect.
- **Error:** semantic red (retained from prior token set as a placeholder — reconfirm exact value at implementation), never conveyed by color alone — pair with icon + text.

### Amount Display (signature component)
The single most important visual element in the app. Bold weight, Display-scale size, tabular numerals (`tnum` feature) for perfect alignment in receipts/lists, Ink color (not Navy — Navy is reserved for actions, not display of neutral financial fact). Never uses gradient text or decorative treatment.

### Navigation
- Bottom tab bar (mobile-native pattern) or platform-standard nav; active state indicated by Navy icon/label, inactive by Muted ink. No color-only differentiation — active state also gets a weight or fill change for colorblind users.

## 6. Do's and Don'ts

### Do:
- **Do** use tabular numerals and bold weight for every payment amount, FX rate, and fee display.
- **Do** keep Navy to ≤10% of any screen's surface area — reserve it for actions and financial emphasis, not decoration.
- **Do** maintain ≥4.5:1 contrast for all body and label text, including "muted" secondary text.
- **Do** keep motion restrained: transitions on state change only, no choreographed entrances.
- **Do** design every balance/rate display as pass-through information, never as a Paycif-held balance.

### Don't:
- **Don't** use gradient text, glassmorphism-as-default, or neon accents — this is explicitly rejected per PRODUCT.md's crypto/DeFi anti-reference.
- **Don't** design UI that resembles traditional Thai bank apps (dense forms, dated iconography, low-contrast government-style layouts) — the other named anti-reference from PRODUCT.md.
- **Don't** apply a drop shadow to any static, at-rest element — flat by default, per the Flat-at-Rest Rule.
- **Don't** use a serif or second display typeface anywhere; one geometric/technical sans carries the entire hierarchy.
- **Don't** use side-stripe borders, tiny uppercase eyebrows, or numbered section markers as default scaffolding — general anti-slop bans apply project-wide.
