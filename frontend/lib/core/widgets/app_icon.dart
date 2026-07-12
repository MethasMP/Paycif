import 'package:flutter/widgets.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

/// Fixed icon size scale — no in-between values (e.g. 14, 22, 26, 28, 56, 80px)
/// allowed anywhere else in the app. Outdoor/one-handed legibility per PRODUCT.md
/// depends on icons never shrinking below [sm].
enum AppIconSize {
  xs(16),
  sm(20),
  md(24),
  lg(32),
  xl(64);

  final double px;
  const AppIconSize(this.px);
}

/// Two-weight icon vocabulary per DESIGN.md §5: [PhosphorIconsRegular] at rest,
/// [PhosphorIconsFill] (or an explicit [activeIcon]) when active/selected/emphasized.
/// This is the only place [phosphoricons_flutter] should be imported directly —
/// call sites should go through [AppIcon] instead of `Icon(PhosphorIcons*.x)` so the
/// weight and size vocabulary can't silently drift per screen.
class AppIcon extends StatelessWidget {
  final IconData icon;
  final IconData? activeIcon;
  final bool isActive;
  final AppIconSize size;
  final Color? color;
  final String? semanticLabel;

  const AppIcon(
    this.icon, {
    super.key,
    this.activeIcon,
    this.isActive = false,
    this.size = AppIconSize.md,
    this.color,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedIcon = isActive ? (activeIcon ?? icon) : icon;
    return PhosphorIcon(
      resolvedIcon,
      size: size.px,
      color: color,
      semanticLabel: semanticLabel,
    );
  }
}
