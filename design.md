นี่คือเอกสาร `design.md` ฉบับสมบูรณ์ที่รวบรวมทั้ง **Design System (Tokens, Components, Screens)** และ **Typography Rationale (การวิเคราะห์และตัดสินใจเลือกฟอนต์)** ไว้ในไฟล์เดียว 

เอกสารนี้ถูกโครงสร้างแบบ **Declarative & Context-Engineered** เพื่อให้ AI Code Generator (เช่น Cursor, Copilot, Claude, GPT-4) สามารถอ่านและแปลงเป็น Flutter UI Code, Theme Data และ Widget Tree ได้ทันทีโดยไม่สับสนครับ

คุณสามารถ Copy โค้ดด้านล่างไปบันทึกเป็นไฟล์ `design.md` ได้เลยครับ

```markdown
# Paycif Design System & Visual Specifications v1.0
**Product:** Cross-border PromptPay payment orchestrator (Tourist App)
**Target Framework:** Flutter (iOS + Android)
**Design Paradigm:** Declarative, Token-Driven, Outdoor-Optimized Fintech
**Context Engineering Note:** This document is structured for direct parsing by LLMs/Code Generators. Design tokens are provided in JSON. Component specs follow a strict property-state-variant model. UX research, user flows, and business logic are intentionally excluded to maintain strict UI/Visual scope.

---

## 1. Design Philosophy & Typography Strategy

### 1.1 Core Principles
- **Warm Precision:** Approachable interface with deliberate, weighted typography for financial moments.
- **Outdoor-First:** Designed for 400+ nit screens in direct sunlight. High contrast, generous spacing, 48dp minimum touch targets.
- **Optimistic Speed:** Mask network latency (3-5s card auth) with immediate visual feedback. UI transitions before backend confirms.
- **Merchant-Zero:** Tourist app must work seamlessly with existing PromptPay QR infrastructure without confusing the merchant.

### 1.2 Typography Strategy: The IBM Plex Sans Decision
**Selected Typeface:** `IBM Plex Sans` (UI/Body) + `IBM Plex Sans Thai` (Thai Fallback)
**Rejected Alternative:** `DM Sans` + `DM Serif Display`

**Rationale for Context Engineers & Developers:**
While `DM Serif Display` offers superior "emotional weight" for financial numerals, **IBM Plex Sans** was selected as the optimal choice for Paycif based on the following constraints:
1. **Multi-language & SE Asia Context:** IBM Plex natively supports Thai (Loopless/Looped) and CJK. Paycif operates in Thailand; merchant names and localized UI elements require robust Thai rendering without relying on disjointed system fallbacks.
2. **Outdoor Legibility:** IBM Plex Sans maintains consistent stroke weight and stable contrast in direct sunlight/glare, whereas DM Sans's low-contrast design can blur at small sizes outdoors.
3. **Development Simplicity:** A single, comprehensive font family reduces CSS/Theme complexity and prevents font-flickering (FOUT) during multi-language loads.

**Injecting "Distinctive Elements" (Compensating for Sans-Serif Neutrality):**
To prevent the UI from feeling "generic corporate" and to give financial amounts the psychological weight that a Serif font would provide, we enforce the following strict typographic treatments:
- **Amount Treatment:** Payment amounts *must* use `Bold` (700) weight + increased `letter-spacing` (1.5px) + `primary.900` color. 
- **Tabular Numerals:** Enable `tnum` (tabular numbers) font feature for all financial figures to ensure perfect vertical alignment in receipts and lists.
- **Gold Accents:** Use `accent.500` (Gold) strictly for value indicators (FX rates, success states) to inject premium "Warm Precision" into the neutral sans-serif canvas.

---

## 2. Design Tokens (Global Variables)

### 2.1 Color System
Optimized for high outdoor visibility and low-light environments.

```json
{
  "colors": {
    "primary": {
      "50": "#E6F7F5", "100": "#B3E8E1", "200": "#80D9CD", "300": "#4DCAB9",
      "400": "#26BFA9", "500": "#00A896", "600": "#008F7F", "700": "#007669",
      "800": "#005D53", "900": "#028090"
    },
    "accent": {
      "50": "#FEF6E0", "100": "#FDECC1", "200": "#FCE3A2", "300": "#FBD983",
      "400": "#FAD064", "500": "#F4B41A", "600": "#D49A00", "700": "#B48100",
      "800": "#946900", "900": "#745100"
    },
    "semantic": {
      "success": { "light": "#D1FAE5", "default": "#10B981", "dark": "#047857" },
      "error": { "light": "#FEE2E2", "default": "#EF4444", "dark": "#B91C1C" },
      "warning": { "light": "#FEF3C7", "default": "#F59E0B", "dark": "#D97706" }
    },
    "surface": {
      "canvas": "#F8FAFC", "default": "#FFFFFF", "elevated": "#FFFFFF",
      "overlay": "rgba(15, 23, 42, 0.6)", "scrim": "rgba(0, 0, 0, 0.5)"
    },
    "text": {
      "primary": "#0F172A", "secondary": "#64748B", "tertiary": "#94A3B8",
      "inverse": "#FFFFFF", "disabled": "#CBD5E1"
    },
    "border": { "default": "#E2E8F0", "focus": "#00A896", "error": "#EF4444" }
  }
}
```

### 2.2 Typography System
```json
{
  "typography": {
    "fontFamily": {
      "primary": "IBM Plex Sans",
      "thai": "IBM Plex Sans Thai",
      "fallback": "SF Pro Display, Roboto, Noto Sans, sans-serif"
    },
    "scale": {
      "display": { "size": 48, "weight": "Bold", "lineHeight": 1.2, "letterSpacing": 1.5, "usage": "Payment amounts" },
      "h1": { "size": 32, "weight": "SemiBold", "lineHeight": 1.3, "letterSpacing": -0.3, "usage": "Receipt totals" },
      "h2": { "size": 24, "weight": "SemiBold", "lineHeight": 1.3, "letterSpacing": -0.2, "usage": "Section headers" },
      "h3": { "size": 20, "weight": "Medium", "lineHeight": 1.4, "letterSpacing": 0, "usage": "Card stats" },
      "bodyLg": { "size": 16, "weight": "Regular", "lineHeight": 1.5, "letterSpacing": 0, "usage": "Body text (min outdoor size)" },
      "body": { "size": 14, "weight": "Regular", "lineHeight": 1.5, "letterSpacing": 0, "usage": "Labels" },
      "caption": { "size": 12, "weight": "Medium", "lineHeight": 1.4, "letterSpacing": 0.2, "usage": "Metadata" }
    },
    "fontFeatures": {
      "amounts": "tnum",
      "body": "calt, liga"
    }
  }
}
```

### 2.3 Spacing, Radii, Elevation & Motion
```json
{
  "spacing": { "grid": 4, "tokens": { "xs": 4, "sm": 8, "md": 12, "lg": 16, "xl": 24, "2xl": 32, "3xl": 48 } },
  "radii": { "sm": 8, "md": 12, "lg": 16, "xl": 24, "full": 9999 },
  "elevation": {
    "sm": "0 1px 2px rgba(15,23,42,0.05)",
    "md": "0 4px 6px -1px rgba(15,23,42,0.1)",
    "lg": "0 10px 15px -3px rgba(15,23,42,0.1)"
  },
  "motion": {
    "duration": { "instant": 100, "fast": 200, "normal": 300, "deliberate": 700 },
    "easing": { "standard": "cubic-bezier(0.4, 0.0, 0.2, 1)", "decelerate": "cubic-bezier(0.0, 0.0, 0.2, 1)" }
  }
}
```

---

## 3. Component Library

### 3.1. Buttons (`PaycifButton`)
| Property | Type | Default / Variants |
| :--- | :--- | :--- |
| `variant` | Enum | `primary` (Teal 500), `secondary` (Outline), `accent` (Gold 500), `ghost` |
| `size` | Enum | `md` (H: 48px), `lg` (H: 56px - *Thumb Zone optimized*) |
| `state` | Enum | `idle`, `loading` (Spinner, disables tap), `disabled` (Opacity 0.5) |
| `typography` | String | `bodyLg`, `weight: SemiBold` |
| `borderRadius`| Double | `radii.full` (Pill shape) |

### 3.2. Transaction Card (`FxBreakdownCard`)
Used to display transparent FX rates and fees.
- **Container:** `surface.elevated`, `radii.lg`, `elevation.md`, `padding.xl`.
- **Layout:** Column.
  - Row 1: "Amount" (`body`, `text.secondary`) | "1,000 THB" (`h2`, `text.primary`).
  - Divider: `height: 1px`, `color: border.default`.
  - Row 2: "FX Rate" (`caption`) | "1 USD = 36.5 THB" (`body`, `accent.500`, `SemiBold`).
  - Row 3: "Network Fee" (`caption`) | "0.50 USD" (`body`).
  - Row 4: "Total" (`h1`, `primary.900`) | "27.50 USD" (`display`, `primary.500`, `Bold`, `tnum`).

### 3.3. Bottom Sheet (`ActionSheet`)
- **Behavior:** Draggable, snaps to 50% and 100% height. Backdrop: `surface.scrim`.
- **Handle:** `width: 40px`, `height: 4px`, `radii.full`, `color: text.tertiary`, centered top margin `spacing.sm`.
- **Header:** `h2` aligned left, Close Icon (X) aligned right.

### 3.4. QR Scanner Overlay (`ScannerOverlay`)
- **Background:** Full-screen Camera Preview.
- **Overlay:** `surface.overlay` with transparent cutout (280x280dp, centered).
- **Targeting Brackets:** 4x L-shapes at cutout corners. **Color:** `accent.500` (Gold), **Stroke:** 4px.
- **Top Safe Area:** Back button (Left), Flash/Torch Toggle (Right - *Critical for low-light*).
- **Bottom Safe Area:** Container (`surface.default`, top `radii.lg`) with "Enter Merchant ID Manually" text button.

---

## 4. Screen Layout Specifications

### 4.1. Transaction Review (`ReviewScreen`)
*Context: Needs immediate trust and clarity before committing funds.*
- **App Bar:** Transparent, Title: "Review Payment".
- **Body (Scrollable):**
  - **Merchant Header:** Avatar (Circle, `primary.50` bg with initials), Name (`h2`), Location (`caption`).
  - **Amount Display:** `display` typography, centered, `primary.900`.
  - **FX Breakdown Card:** (See 3.2).
  - **Payment Method Selector:** Chips for Apple Pay / Google Pay / Card.
- **Bottom Action Bar (Pinned):** `PaycifButton` (Variant: `primary`, Size: `lg`). Text: "Pay [Amount]".

### 4.2. Processing & Success (`StatusScreen`)
*Context: Optimistic UI to mask network latency (3-5s).*
- **Processing State:** Full screen `surface.default`. Center: Custom `CircularProgressIndicator` (Teal/Gold gradient). Text: "Securing transaction...".
- **Success State:** 
  - Animation: Subtle scale-in of Success Checkmark (Lottie).
  - Header: "Payment Successful" (`h1`, `success.default`).
  - Receipt Card: Mimics physical receipt. Includes QR code for merchant verification.
  - Action: "Done" button (`primary`, full width).

---

## 5. Visual States & Optimistic UI Rules

| State | Visual Treatment | Flutter Implementation Note |
| :--- | :--- | :--- |
| **Loading (Skeleton)** | Shimmer effect using `primary.50` and `surface.canvas`. | Use `shimmer` package. Apply to `FxBreakdownCard` while fetching live rates. |
| **Optimistic Success** | Immediate UI transition to Success Screen before backend webhook confirms. | Update local state immediately on button tap. Revert on WebSocket error. |
| **Network Error** | Bottom Snackbar (Red background, White text). "Connection lost. Retry?" | Use `ScaffoldMessenger.showSnackBar`. Do not block main UI thread. |
| **Low Signal** | Top Banner (Gold background, Dark text). "Weak signal - Transaction queued" | Persistent banner below App Bar if `ConnectivityResult.none`. |

---

## 6. Accessibility & Localization Constraints

### 6.1. Contrast & Outdoor Visibility
- **WCAG AAA Compliance:** All text on `primary.500` must be `text.inverse` (White). Contrast ratio > 7:1.
- **Outdoor Mode:** If ambient light sensor detects high lux, automatically increase font weight to `SemiBold` and boost border widths by `1px`.

### 6.2. Multi-language UI (i18n)
- **Primary:** English (LTR).
- **Secondary:** Chinese, Japanese, Korean, Thai.
- **Thai Fallback Strategy:** Use `IBM Plex Sans Thai` (Loopless variant preferred for modern UI). Fallback to `Noto Sans Thai` if glyphs are missing.
- **Dynamic Type:** UI must support OS-level font scaling up to `1.5x`. Use `FittedBox` for fixed-width amount displays to prevent overflow.
- **Number Formatting:** Use `intl` package. (THB: `฿1,000.00`, JPY: `¥4,100` no decimals).

---

## 7. Flutter Architecture Mapping (For Code Generation)

When generating the UI code, map the tokens to the following Flutter structure:

```dart
// theme/paycif_theme.dart
import 'package:flutter/material.dart';

ThemeData paycifTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.light(
    primary: Color(0xFF00A896),
    secondary: Color(0xFFF4B41A),
    surface: Color(0xFFFFFFFF),
    background: Color(0xFFF8FAFC),
  ),
  fontFamily: 'IBM Plex Sans',
  textTheme: TextTheme(
    displayLarge: TextStyle(
      fontSize: 48,
      fontWeight: FontWeight.bold,
      letterSpacing: 1.5, // Distinctive Element: Wide tracking for amounts
      height: 1.2,
      fontFeatures: [FontFeature.tabularFigures()], // Distinctive Element: tnum
      color: Color(0xFF028090), // primary.900
    ),
    bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      minimumSize: Size(double.infinity, 56),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
      backgroundColor: Color(0xFF00A896),
      foregroundColor: Colors.white,
    ),
  ),
);
```

### Folder Structure
```text
lib/
├── theme/          # paycif_theme.dart, tokens.dart
├── components/     # buttons/, cards/, inputs/, sheets/, feedback/
├── screens/        # home, scan, review, success, history
└── utils/          # formatters.dart (intl), haptics.dart
```
```

### คำแนะนำเพิ่มเติมสำหรับการนำไปใช้งาน (Context Engineering Workflow)
1. **การป้อนให้ AI (Prompting):** เมื่อคุณใช้ Cursor หรือ Copilot ให้ Copy ไฟล์ `design.md` นี้ใส่ใน `.cursorrules` หรือแนบเป็น Context (`@design.md`) แล้วสั่งว่า *"Generate the `FxBreakdownCard` widget based on the design system specs, ensuring the tabular figures and letter-spacing for the total amount are applied exactly as defined."* AI จะเขียนโค้ดที่แม่นยำระดับ Production-ready ให้ทันที
2. **Font Assets:** อย่าลืมเพิ่ม `IBM Plex Sans` และ `IBM Plex Sans Thai` เข้าไปใน `pubspec.yaml` และตั้งค่า `fontFamilyFallback` ใน Flutter ให้เรียบร้อยเพื่อให้รองรับภาษาไทยอย่างสมบูรณ์ครับ