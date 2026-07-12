# Paycif Design Board Consensus Report: The "Slide to Pay" Gesture vs. Traditional Button

**Date:** July 10, 2026  
**Board Members in Attendance:**
1. **Katie Dill** (Head of Design @ Stripe)
2. **Ethan Eismann** (CDO @ Nubank)
3. **Josh Payton** (VP of Design @ Wise)
4. **David Fock** (CPDO @ Klarna)
5. **Alexandre Deffenain** (Head of Product Design @ Revolut)
6. **Robert Andersen** (former Head of Design @ Cash App)
7. **Stephen Lemay** (VP of Human Interface Design @ Apple)
8. **Connie Yang** (former Design Director @ Coinbase)
9. **Baiju Bhatt** (former CCO @ Robinhood)
10. **Orlando Baeza** (VP of Brand & Creative @ Chime)

---

## 1. Executive Summary & Design Challenge

This document details the debate and consensus resolution of the Paycif Design Board regarding the transaction-confirmation mechanism. 

The core topic of debate was a critique of the **"Slide to Pay"** sliding gesture:
> *"Is a sliding gesture really necessary? Isn't it too high-friction? If a user has wet hands, or their screen has touch responsiveness issues (very common for tourists in hot/humid climates), they won't be able to pay. A simple button is standard."*

The board split into distinct cohorts defending the visual momentum and friction-safety of the swipe, arguing the critical accessibility/usability limitations of touch gestures, and proposing platform-level hybrid fallbacks. The result is a unified specification that balances absolute error protection with guaranteed fail-safe execution under harsh environmental conditions.

---

## 2. The Debate: Transcripts & Perspectives

### Round 1: Defending the Slide — Visual Momentum & Security Guardrails

*The meeting opens with a defense of the swipe/sliding gesture as a tool for safety, psychology, and intent validation.*

* **Robert Andersen (Cash App):** "We can’t just dismiss the swipe as 'friction.' It’s *intentional* friction. In Cash App, the physical momentum of moving money matters. A simple button is a liability in a pocket, a crowded market, or when a user is distracted. If a phone is unlocked in someone’s hand and they bump into a vendor, a single tap can initiate a payment. The sliding gesture forces the motor cortex to declare intent. It provides psychological closure—sending money has weight, and the swipe visualizes that momentum."
* **Alexandre Deffenain (Revolut):** "Exactly, Robert. It’s about accidental transaction prevention and confirmation. A payment is not a simple 'Next Page' navigation. It is a legal, immutable transfer of capital. In Revolut, we use sliding and drag gestures specifically to slow the user down at critical decision junctions. If we replace the slider with a simple tap, we will see a 10x surge in customer support tickets claiming 'I clicked it by mistake.' The swipe builds a sensory wall that guarantees user intent."
* **Connie Yang (Coinbase):** "To piggyback on Alexandre's point, visual momentum builds trust. In Web3 and Coinbase, we realized that when transactions happen too quickly, users actually feel *less* secure. They think, 'Did that go through? Who did it go to?' The sliding animation gives the system time to display real-time ledger states, loading states, and transaction routing. It bridges the gap between digital speed and physical trust."
* **Baiju Bhatt (Robinhood):** "We saw this clearly at Robinhood when we introduced the 'Swipe Up to Trade' gesture. Yes, it was novel, but it also democratized the feeling of execution. The physical swipe makes the transaction feel tangible. But we must admit: if the gesture fails mechanically due to physical constraints, the sensation of control immediately turns into anger. We must protect the sensation of execution while solving the mechanics of failure."

---

### Round 2: The Accessibility & Usability Case

*The usability advocates counter with real-world accessibility issues, climate realities, and lower-tier hardware.*

* **Katie Dill (Stripe):** "We need to step out of our Silicon Valley design labs. Paycif is meant for Southeast Asian street markets. Tourists and locals alike are using this in 38°C (100°F) heat with 90% humidity. Sweat on fingers is not an edge case—it is the baseline. When a screen is covered in moisture, capacitive touch layers fail to register continuous drag vectors. The swipe gesture breaks down. A user is left standing at a food stall, holding up a line, repeatedly failing to complete a transaction. At Stripe, we design for global optimization. Friction should be cognitive (validation of amount), not mechanical (struggling with a wet screen)."
* **Ethan Eismann (Nubank):** "Katie is 100% right. In Brazil, we see millions of transactions on sub-$100 Android devices with degraded digitizers and cracked screens. These screens do not have high-frequency touch polling. They drop touch events mid-gesture. If a slider requires a continuous `x-axis` offset of 200 pixels, and the digitizer drops the connection at pixel 120, the payment fails. We cannot lock users out of their money because of their hardware. We are designing a financial utility, not a mobile game."
* **Orlando Baeza (Chime):** "Let's also talk about physical and motor impairment. A sliding gesture requires fine motor control and coordinate tracking. For an elderly user, a user with hand tremors, or someone carrying shopping bags in one hand, the swipe gesture is a massive accessibility barrier. Chime's core philosophy is financial inclusion. If a user cannot pay because they cannot draw a straight line on glass, we have failed the baseline test of human-centered design."
* **Josh Payton (Wise):** "At Wise, we look at the cognitive friction of moving money across borders. If the interface introduces physical friction that frustrates the user, they lose confidence in the service. They don't think, 'Oh, my screen is wet.' They think, 'This app is broken.' A standard, high-contrast, large-tap-target button is the universal design language of the internet because it works universally. If we deviate from that, we must have an bulletproof reason and a perfect fallback."
* **David Fock (Klarna):** "But a standard button is boring, Josh. It makes the app feel like a utility bill payment screen. We want Paycif to feel premium. However, I agree that a failed swipe is the ultimate brand killer. If the user is stuck swiping five times, the design has backfired. We need to preserve the safety of the slider but ensure it has an escape hatch that feels just as intentional."

---

### Round 3: The Hybrid Resolution

*The board aligns on a unified solution that preserves the safety and intent of the gesture while introducing environment-aware and accessibility-friendly fallbacks.*

* **Stephen Lemay (Apple):** "We don't have to choose between a gesture and a button. Apple’s Human Interface Guidelines have long dealt with this. The slider provides the guardrail protection we need. However, we can integrate a dynamic fallback mechanism. If the system detects a swipe gesture is repeatedly unsuccessful—say, two failed swipe attempts that terminate halfway—or if OS-level accessibility settings (like VoiceOver or AssistiveTouch) are enabled, the UI should instantly morph the slider into an explicit **'Double-Tap to Pay'** or **'Press & Hold'** button with a progress ring. This gives us the best of both worlds: gesture-based intent by default, and high-reliability fallback by context."
* **Katie Dill (Stripe):** "I can support that. The 'Press & Hold' (long-press) action for 1.5 seconds is incredibly resilient. It works even on wet screens because it doesn't require coordinate movement—only continuous contact on a single cluster of capacitive nodes. A progress circle wraps the button as you hold, building the same psychological closure and intent validation as the swipe."
* **Robert Andersen (Cash App):** "A 1.5-second Press & Hold with a haptic ramp-up is beautiful. It maintains the sensory weight of the transaction. The haptic motor should buzz with increasing frequency as the progress ring fills, ending in a heavy 'thud' success vibration. It matches the visual momentum of the slider."
* **Alexandre Deffenain (Revolut):** "Agreed. The default view is the slider. If the swipe starts and fails twice, or if the user taps the slider directly three times without dragging, we morph it into the 'Press & Hold' button. The transition must be fluid, using standard spring physics so it feels like a physical mechanical change."

---

## 3. Consensus Resolution: The "Intent Engine" UI

The board finalized the **"Intent Engine"** framework to govern all transaction confirmations.

```mermaid
stateDiagram-v2
    [*] --> SliderActive : Default State
    SliderActive --> Success : Successful Swipe (100% X-Axis)
    SliderActive --> CheckConditions : Swipe Fails / Mid-drop / Tap-Only
    CheckConditions --> PressAndHoldActive : 2x Failures OR Accessibility Enabled
    CheckConditions --> SliderActive : Swipe Retry
    PressAndHoldActive --> Success : 1.5s Continuous Hold (Progress Ring Fills)
    PressAndHoldActive --> PressAndHoldActive : Release early (Resets progress)
    Success --> [*]
```

### A. Default State: The Haptic Slider
* **Visuals:** A low-profile horizontal track (`#0A0E1A` on light, `#F8F9FC` on dark) containing a sliding handle with the brand Teal-Cyan (`#00F5D4`).
* **Physics:** Spring-loaded return. If released before `90%` completion, the handle snaps back to the origin with a soft deceleration animation (150ms).
* **Feedback:** A light haptic tick (e.g. `selectionChanged`) matches the slider crossing increments of `25%`, `50%`, and `75%`.

### B. Fail-Safe Morph State: Tactile Long-Press (Press & Hold)
* **Trigger Conditions:**
  1. Two aborted swipe gestures (handle dragged past `10%` but released before `90%`).
  2. Three rapid taps directly on the slider track without horizontal movement.
  3. System-level accessibility settings (VoiceOver, TalkBack, or motor-assistive features) are active.
* **Morph Animation:** The slider track collapses inwards over 200ms, morphing into a large, centered circular button (`56px` height/width).
* **Action:** **Press & Hold for 1.5 Seconds**.
* **Visual Progress:** A thick radial progress border (`#00F5D4`) sweeps around the circular button as the user holds.
* **Haptic Ramp:** Haptic pulses escalate in frequency from 10Hz to 80Hz, terminating in a deep, satisfying confirmation click upon completion.

---

## 4. Real-World Fintech Implementations

To validate this approach, the board analyzed how top industry leaders handle payment validation and gesture friction:

### 1. Cash App
* **Mechanism:** Relies on clean, rapid taps combined with immediate, high-quality device haptics. Cash App prioritizes extreme speed but implements strict **"Confirm Security Pin"** or biometric check (FaceID/TouchID) overlays immediately after the tap if the transaction amount exceeds a dynamic risk threshold. This shifts friction from a physical swipe to biometric verification.

### 2. Wise
* **Mechanism:** Wise utilizes standard button states but segments transactions into a clear multi-step flow. The final validation is a standard flat button. To prevent accidental transfers, Wise displays a comprehensive "Review details" screen where the button is disabled for the first `500ms` to force visual inspection of the exchange rates and fees before a tap can be registered.

### 3. Stripe
* **Mechanism:** Stripe's mobile SDK elements (like the Payment Sheet) avoid complex gestures. They enforce standard button taps, prioritizing maximum conversion and accessibility across millions of low-end merchant devices. Stripe handles safety and fraud prevention via server-side machine learning and risk engines (Radar) rather than introducing physical UI friction.

### 4. Apple Pay
* **Mechanism:** The gold standard of hybrid safety. Apple avoids sliders entirely. Confirmation requires a physical double-click of the side button (ensuring hardware-level intentionality) combined with face/finger biometrics. If FaceID fails, it instantly falls back to a numeric passcode keypad.

---

## 5. Final Approvals & Signatures

By signing below, the design leaders endorse the implementation of the **Intent Engine** hybrid confirmation UI for Paycif.

* **Katie Dill** (Stripe) — *Approved for global conversion reliability and wet-screen resilience.*
* **Ethan Eismann** (Nubank) — *Approved for low-end device compatibility and accessibility.*
* **Josh Payton** (Wise) — *Approved for cross-border transaction clarity.*
* **David Fock** (Klarna) — *Approved for maintaining high brand premiumness.*
* **Alexandre Deffenain** (Revolut) — *Approved for preventing accidental support-ticket volume.*
* **Robert Andersen** (Cash App) — *Approved for physical transaction weight and premium haptics.*
* **Stephen Lemay** (Apple) — *Approved for system-level fallback compliance.*
* **Connie Yang** (Coinbase) — *Approved for trust-building visual cues.*
* **Baiju Bhatt** (Robinhood) — *Approved for intentional and engaging execution mechanics.*
* **Orlando Baeza** (Chime) — *Approved for universal inclusivity and warmth.*
