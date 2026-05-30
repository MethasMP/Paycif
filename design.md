# Paycif Design System v1.0
> Simple like Stripe. Distinct like Paycif.

## 0. Design Principles
1. **Clarity > Decoration** — พื้นขาว 90%, เนื้อหานำทาง
2. **One Action Per Screen** — ปุ่มทองคือพระเอกเสมอ
3. **Thai Money is Green** — ตัวเลข THB ใช้สีเขียวเท่านั้น
4. **Familiar but Unmistakable** — layout มาตรฐานโลก, สีคือลายเซ็น

## 1. Brand Colors
### Core
| Token | Hex | Usage |
| --- | --- | --- |
| primary-600 | #0F6E56 | Amount, links, active icon, success |
| primary-800 | #085041 | Hover, pressed |
| primary-100 | #E1F5EE | Icon bg, chip, subtle highlight |
| accent-500 | #EF9F27 | Primary CTA background ONLY |
| accent-300 | #FAC775 | Dark mode CTA |
| accent-900 | #412402 | Text on gold |

### Neutrals
- bg-primary: #FFFFFF
- bg-secondary: #F7F7F5
- border: #E5E5E3
- text-primary: #111111
- text-secondary: #666664
- text-tertiary: #AAAAAA

### Semantic
- success: primary-600
- error: #D92D20
- warning: #F79009
- info: #1570EF

**Rules**
- Gold never used as text on white (fails WCAG). Use only as CTA bg.
- Teal never used as large background (except splash). Use for data.
- Max 1 accent color per screen.

### Dark Mode
- bg: #0B0F0E, surface: #141A18
- primary: #2BBF9E, accent: #FAC775, text-primary: #F5F5F5

## 2. Typography
**Pairing**
- Latin/Numbers: Inter (400, 500, 600)
- Thai: IBM Plex Sans Thai (400, 500, 600)

**Scale**
| Name | Size/Line | Weight | Use |
| --- | --- | --- | --- |
| Display | 32/40 | 600 | Ready to Pay |
| H1 | 24/32 | 600 | Screen title |
| H2 | 20/28 | 500 | Merchant name |
| Body | 16/24 | 400 | Descriptions |
| Caption | 13/20 | 400 | Time, ref |
| Numeric | 28/36 | 500 | THB amount — tabular nums |

Thai line-height +4px vs English.

## 3. Spacing & Grid
- Base unit: 8px
- Margins: 20px horizontal
- Vertical rhythm: 8, 16, 24, 32, 48
- Corner radius: 12px (cards), 24px (hero), 999px (pills)
- Elevation: 0 (most), 1 (CTA): 0 2px 8px rgba(15,110,86,0.08)

## 4. Iconography
- Library: Phosphor Regular, 24px, stroke 1.75
- Active: fill primary-600, Inactive: text-tertiary
- Icon containers: 40px circle, bg primary-100

## 5. Components
### Primary CTA (Scan)
- 72px circle, bg accent-500, icon QR 28px color accent-900
- Shadow soft, pulse 1.5s on idle
- Only one per screen

### Button Secondary
- Height 44px, border 1px primary-600, text primary-600, bg transparent

### List Item (Transaction)
- Left: 40px avatar, Center: name (H2) + time (caption), Right: amount (numeric, primary-600)

### Slip Screen
- White bg, center check 64px primary-600
- Fields bilingual: EN 14px medium / TH 12px regular below
- Amount 32px primary-600

## 6. Patterns
**Home** — White, headline, gold CTA center, no hero card
**Pay Flow** — Scan → Confirm (amount large green) → FaceID → Slip (stays)
**Navigation** — Bottom bar 4 items, center is gold CTA

## 7. Localization
- UI follows device language
- Slip always bilingual: English first, Thai second in smaller gray
- Dates: EN "18 May 2025" / TH "18 พ.ค. 68" on second line
- Numbers: Western digits, THB symbol before

## 8. Differentiation Strategy
1. **Gold Pulse** — only Paycif has warm gold action in SEA fintech
2. **Green Money** — all THB amounts are teal, creates memory
3. **Thai Micro-detail** — Buddhist year, PromptPay label in Thai on slip
4. **No Cards** — unlike KBank/SCB, we use air and whitespace like Stripe

## 9. Accessibility
- Contrast: text-primary on white 16.1:1, gold bg with #412402 text 7.1:1
- Touch target min 44px
- Dynamic type support +20%

## 10. Motion
- Duration 150ms, ease-out
- Success: check scale 0.8→1.0 + haptic
- No slide transitions, use fade

---
Implement in Figma with these tokens. Do not add new colors.
