# 🧠 MOBILE CHECKPOINT: Paycif

**Platform**: iOS & Android\
**Framework**: Flutter\
**Files Read**: Universal & Platform-Specific

## 3 Principles I Will Apply

1. **Touch zones first**: Every button must be at least 48x48dp.
2. **No Spinner Purgatory**: Use optimistic updates and skeletons (already partially implemented).
3. **Haptic Reality**: Use platform-appropriate haptics (Light/Medium/Heavy) based on context.

## Anti-Patterns I Will Avoid

1. **ScrollView for History**: I will ensure `ListView.builder` or `SliverList` is used for
   transaction history to prevent memory spikes.
2. **Generic Back Buttons**: Ensure iOS uses edge-swipe and Android respects system back.
