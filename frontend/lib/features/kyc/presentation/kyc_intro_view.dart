import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:frontend/core/widgets/app_icon.dart';

/// The explainer shown when KYC is in [KycInitial].
///
/// Walks the user through what identity verification involves before the
/// hosted verification webview launches. [onGetStarted] should trigger the
/// cubit's `initKyc()` to begin the real flow.
class KycIntroView extends StatelessWidget {
  const KycIntroView({super.key, required this.onGetStarted});

  final VoidCallback onGetStarted;

  static const _steps = <_KycStep>[
    _KycStep(
      icon: PhosphorIcons.identificationCard,
      title: 'Photograph your ID or passport',
      subtitle: 'Hold it steady so the details are clear and readable.',
    ),
    _KycStep(
      icon: PhosphorIcons.userFocus,
      title: 'Take a quick selfie',
      subtitle: 'This confirms the document belongs to you.',
    ),
    _KycStep(
      icon: PhosphorIcons.clock,
      title: 'Wait a moment for the result',
      subtitle: 'We\'ll check everything and update your status automatically.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryTeal.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: AppIcon(
                        PhosphorIcons.shieldCheck,
                        color: AppTheme.primaryTeal,
                        size: AppIconSize.lg,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Verify your identity',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'A few quick steps keep your payments secure.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ...List.generate(_steps.length, (i) {
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: i == _steps.length - 1 ? 0 : 16,
                      ),
                      child: _StepTile(index: i + 1, step: _steps[i]),
                    );
                  }),
                  const SizedBox(height: 24),
                  _TimeChip(theme: theme),
                  const SizedBox(height: 16),
                  _UnlockBanner(theme: theme),
                ],
              )
                  .animate()
                  .fadeIn(duration: 350.ms)
                  .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onGetStarted,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Get started',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.index, required this.step});

  final int index;
  final _KycStep step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.primaryTeal.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: AppIcon(step.icon, color: AppTheme.primaryTeal, size: AppIconSize.md),
            ),
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryTeal,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$index',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step.title,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                step.subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(
            PhosphorIcons.timer,
            size: AppIconSize.xs,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 6),
          Text(
            'Takes about 2–5 minutes',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _UnlockBanner extends StatelessWidget {
  const _UnlockBanner({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.primaryTeal.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.primaryTeal.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(PhosphorIcons.lockKeyOpen, color: AppTheme.primaryTeal, size: AppIconSize.md),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Once verified, you can pay Thai merchants and unlock higher payment limits.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KycStep {
  const _KycStep({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}
