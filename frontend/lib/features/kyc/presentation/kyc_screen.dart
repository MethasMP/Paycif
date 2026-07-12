import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/l10n/generated/app_localizations.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/kyc/presentation/kyc_intro_view.dart';
import 'package:frontend/features/kyc/presentation/kyc_webview_screen.dart';
import 'package:frontend/features/kyc/presentation/sumsub_kyc_cubit.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:frontend/core/widgets/app_icon.dart';

class KycScreen extends StatefulWidget {
  const KycScreen({super.key});

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  Future<void> _openKycWebView(String kycUrl) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => KycWebViewScreen(
          kycUrl: kycUrl,
          // When Alchemy Pay finishes, it redirects to this prefix.
          // Adjust to match ALCHEMY_PAY_KYC_CALLBACK_URL redirect if needed.
          completionUrlPrefix: 'https://paysif.io/kyc/complete',
        ),
      ),
    );
    // Whether user completed or dismissed — start polling either way.
    if (mounted) {
      context.read<SumsubKycCubit>().onReturnedFromBrowser();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: AppIcon(PhosphorIcons.caretLeft),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: Text(
          l10n.kycAppBarTitle,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      body: BlocConsumer<SumsubKycCubit, KycState>(
        listener: (context, state) {
          if (state is KycUrlReady) {
            _openKycWebView(state.kycUrl);
          }
          if (state is KycVerified) {
            context.pop(true);
          }
        },
        builder: (context, state) {
          if (state is KycInitial) {
            return KycIntroView(
              onGetStarted: () => context.read<SumsubKycCubit>().initKyc(),
            );
          }
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildIcon(state),
                const SizedBox(height: 32),
                _buildTitle(state, theme, l10n),
                const SizedBox(height: 12),
                _buildSubtitle(state, theme, l10n),
                const SizedBox(height: 40),
                _buildAction(context, state, l10n),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildIcon(KycState state) {
    if (state is KycVerified) {
      return AppIcon(PhosphorIcons.shieldCheck, color: AppTheme.successGreen, size: AppIconSize.xl)
          .animate()
          .scale(begin: const Offset(0.5, 0.5), duration: 400.ms, curve: Curves.elasticOut);
    }
    if (state is KycFailed) {
      return AppIcon(PhosphorIcons.shieldWarning, color: AppTheme.errorRed, size: AppIconSize.xl);
    }
    return AppIcon(PhosphorIcons.shield, color: AppTheme.primaryTeal, size: AppIconSize.xl)
        .animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 2.seconds, color: Colors.white.withValues(alpha: 0.4));
  }

  String _titleFor(KycState state, AppLocalizations l10n) {
    if (state is KycLoading) return l10n.kycStatusPreparing;
    if (state is KycUrlReady) return l10n.kycStatusOpening;
    if (state is KycAwaitingResult) return l10n.kycStatusInProgress;
    if (state is KycPolling) return l10n.kycStatusChecking;
    if (state is KycVerified) return l10n.kycStatusComplete;
    if (state is KycFailed) return l10n.kycStatusIssue;
    return l10n.kycAppBarTitle;
  }

  Widget _buildTitle(KycState state, ThemeData theme, AppLocalizations l10n) {
    return Text(
      _titleFor(state, l10n),
      textAlign: TextAlign.center,
      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
    );
  }

  Widget _buildSubtitle(KycState state, ThemeData theme, AppLocalizations l10n) {
    final String text;
    if (state is KycLoading || state is KycUrlReady) {
      text = l10n.kycMessageSettingUp;
    } else if (state is KycPolling) {
      text = l10n.kycMessageWaiting;
    } else if (state is KycAwaitingResult) {
      text = l10n.kycMessageAwaitingResult;
    } else if (state is KycVerified) {
      text = l10n.kycMessageVerified;
    } else if (state is KycFailed) {
      text = state.reason;
    } else {
      text = l10n.kycMessageDefault;
    }

    return Text(
      text,
      textAlign: TextAlign.center,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: state is KycFailed
            ? AppTheme.errorRedText
            : theme.colorScheme.onSurface.withValues(alpha: 0.65),
        height: 1.5,
      ),
    );
  }

  Widget _buildAction(BuildContext context, KycState state, AppLocalizations l10n) {
    if (state is KycLoading || state is KycUrlReady || state is KycPolling) {
      return const CircularProgressIndicator();
    }
    if (state is KycAwaitingResult) {
      return Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () => context.read<SumsubKycCubit>().initKyc(),
            child: Text(l10n.kycReopenVerification),
          ),
        ],
      );
    }
    if (state is KycFailed) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.read<SumsubKycCubit>().initKyc(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryTeal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(l10n.kycTryAgain, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.kycDoThisLater),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}
