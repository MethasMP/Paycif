# 📱 Mobile Design Thinking: Paycif

> **Law: Mobile is NOT a small desktop.**

## Constraints over Aesthetics

- **One-Handed Use**: Crucial interactions (Pay, Top Up) must be in the thumb zone.
- **Battery Conscious**: Minimize heavy animations during low-battery states; prewarm connections to
  save radio on-time.
- **Interruption Handling**: Sessions must persist across backgrounding/foregrounding (implemented
  via heartbeat).

## Touch Psychology

- **Accuracy is low**: We assume the user is walking or distracted.
- **Fitts' Law**: Large targets for primary actions; destructive actions (Delete, Cancel) away from
  edges.
