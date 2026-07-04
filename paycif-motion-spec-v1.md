# Paycif — Motion & Interaction Spec v1
For Flutter implementation. Pairs with the visual design system locked in Phase 1 (see design tokens below).

## Motion principles

1. **Fast, not flashy.** Every transition exists to reduce perceived wait or confirm an action — never decorative. Nothing should feel like it's showing off.
2. **Confidence over delight.** This is a payment app. Motion should make the user feel certain money moved correctly, not entertained.
3. **Interruptible.** Any animation the user might act through (tapping Cancel mid-transition) must not block input.

## Timing tokens

| Token | Duration | Curve | Use case |
|---|---|---|---|
| `motion.instant` | 100ms | linear | Button press feedback (scale down) |
| `motion.fast` | 150ms | easeOut | Toggle, checkbox, chip select |
| `motion.base` | 220ms | easeInOut | Screen-to-screen push/pop, sheet open |
| `motion.slow` | 350ms | easeOut | Success state reveal, confetti-free celebration |
| `motion.number` | 280ms | easeOut | Counting/rolling digit animation |

Flutter: use `Curves.easeOutCubic` for `easeOut`, `Curves.easeInOutCubic` for `easeInOut`.

## Screen-by-screen spec

### 1. Sign-in → Identity check → Create PIN (onboarding chain)
- Transition: horizontal push, `motion.base`, standard iOS/Android platform transition (do not override — users expect native back-swipe behavior here).
- No custom transition. Custom motion on auth screens adds risk without payoff.

### 2. Home → QR scan
- Camera view **scales in from the "Scan to pay" card's position** (shared element transition) — the black card visually "opens into" the camera. `motion.base`, 220ms.
- Corner brackets fade in 80ms after the camera feed is live (avoids flashing static brackets before feed loads).

### 3. QR detected → Payment confirmation
- On successful scan: brackets snap-tighten around the code (`motion.instant`, scale 1.0 → 0.92 → 1.0) + light haptic (`UIImpactFeedbackStyle.medium` / Android `HapticFeedback.mediumImpact`).
- Screen transition: bottom sheet slides up, `motion.base`. Do not fade — sliding communicates "this came from what you just scanned."

### 4. Payment confirmation → Apple Pay / card auth sheet
- This is a native system sheet (`PKPaymentAuthorizationController` / platform pay sheet). No custom motion — do not attempt to theme or intercept its transition.

### 5. Auth success → Payment success state
- Checkmark icon: draws in via stroke animation (SVG path, 0 → 100% over 300ms, `easeOut`) rather than a static icon fade-in. This is the single most important motion moment in the app — the user needs to *feel* the payment completed.
- Amount counts up from 0 to final value over `motion.number` (280ms) using an ease-out digit roll, tabular nums prevent layout shift during the count.
- Haptic: success notification haptic (`UINotificationFeedbackType.success` / Android `HapticFeedback.heavyImpact` then light) — plays at the same frame the checkmark starts drawing, not after.
- No sound by default (silent-mode friendly); if device sound is on and permitted, a single short confirmation tone (<300ms, non-jingle) may play — must respect system silent switch, never overridden.

### 6. Payment declined
- Card/amount shakes horizontally: 3 cycles, 8px amplitude, 300ms total (`Curves.elasticIn`-adjacent — use a manual keyframe, not spring, to avoid overshoot feeling "bouncy" in a failure state).
- Haptic: error notification haptic (`UINotificationFeedbackType.error`).
- Red tint on the amount fades in over `motion.fast`, fades out once user starts a retry action.

### 7. Transaction list → Receipt detail
- Shared element: tapped row's status icon and amount morph into position on the receipt screen (position + scale interpolation, `motion.base`). Everything else on the receipt fades in 60ms after.

### 8. PIN entry error (mismatch on confirm)
- Dots: horizontal shake, 3 cycles, 6px amplitude, 250ms, then clear and reset to empty state.
- Haptic: light error haptic, not the heavy "declined" haptic — this is a lower-stakes error.

### 9. Pull-to-refresh (transaction history)
- Standard platform refresh indicator. Do not custom-brand this control — platform-native refresh is a well-learned pattern and custom versions consistently test worse for perceived responsiveness.

## Haptic reference table

| Event | iOS | Android |
|---|---|---|
| Button tap | `UIImpactFeedbackStyle.light` | `HapticFeedback.lightImpact` |
| QR detected | `UIImpactFeedbackStyle.medium` | `HapticFeedback.mediumImpact` |
| Payment success | `UINotificationFeedbackType.success` | `HapticFeedback.heavyImpact` + `lightImpact` (100ms apart) |
| Payment declined | `UINotificationFeedbackType.error` | `HapticFeedback.heavyImpact` |
| PIN mismatch | `UIImpactFeedbackStyle.light` | `HapticFeedback.lightImpact` |
| Delete account confirm | `UINotificationFeedbackType.warning` | `HapticFeedback.mediumImpact` |

## Explicitly out of scope for v1

- Confetti, particle effects, or celebratory animation beyond the checkmark draw-in and number count-up — this is a utility app, not a rewards app; overly celebratory motion on a payment reads as untrustworthy for a fintech context.
- Custom pull-to-refresh, custom system sheets, custom back-gesture — all use platform defaults.
- Sound design beyond the single optional success tone — full sound design is a Phase 2+ item pending user research on whether tourists want audio feedback in public spaces.

## Open questions for engineering

1. Confirm whether Flutter's `Hero` widget is sufficient for the shared-element transitions in sections 2, 3, and 7, or whether a custom `PageRouteBuilder` is needed for the card-to-camera morph in section 2.
2. Confirm device haptic capability detection — older Android devices may not support `mediumImpact`/`heavyImpact` distinctly; needs a fallback to a single haptic tier.
3. Confirm with SQRIL/payment provider whether payment confirmation can be optimistically shown (with rollback) or must wait for hard confirmation — this changes whether the checkmark draw-in plays before or after settlement confirmation returns.
