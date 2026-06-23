import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/kyc/presentation/kyc_webview_screen.dart';
import 'package:frontend/features/kyc/presentation/sumsub_kyc_cubit.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

class KycScreen extends StatefulWidget {
  const KycScreen({super.key});

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  @override
  void initState() {
    super.initState();
    context.read<SumsubKycCubit>().initKyc();
  }

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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: Text(
          'Identity Verification',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      body: BlocConsumer<SumsubKycCubit, KycState>(
        listener: (context, state) {
          if (state is KycUrlReady) {
            _openKycWebView(state.kycUrl);
          }
          if (state is KycVerified) {
            Navigator.of(context).pop(true);
          }
        },
        builder: (context, state) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildIcon(state),
                const SizedBox(height: 32),
                _buildTitle(state, theme),
                const SizedBox(height: 12),
                _buildSubtitle(state, theme),
                const SizedBox(height: 40),
                _buildAction(context, state),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildIcon(KycState state) {
    if (state is KycVerified) {
      return Icon(PhosphorIcons.shieldCheck, color: Colors.green.shade400, size: 80)
          .animate()
          .scale(begin: const Offset(0.5, 0.5), duration: 400.ms, curve: Curves.elasticOut);
    }
    if (state is KycFailed) {
      return Icon(PhosphorIcons.shieldWarning, color: Colors.red.shade400, size: 80);
    }
    return Icon(PhosphorIcons.shield, color: AppTheme.primaryTeal, size: 80)
        .animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 2.seconds, color: AppTheme.accentGold.withValues(alpha: 0.4));
  }

  String _titleFor(KycState state) {
    if (state is KycLoading) return 'Preparing Verification...';
    if (state is KycUrlReady) return 'Opening Verification...';
    if (state is KycAwaitingResult) return 'Verification In Progress';
    if (state is KycPolling) return 'Checking Your Status...';
    if (state is KycVerified) return 'Verification Complete';
    if (state is KycFailed) return 'Verification Issue';
    return 'Identity Verification';
  }

  Widget _buildTitle(KycState state, ThemeData theme) {
    return Text(
      _titleFor(state),
      textAlign: TextAlign.center,
      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
    );
  }

  Widget _buildSubtitle(KycState state, ThemeData theme) {
    final String text;
    if (state is KycLoading || state is KycUrlReady) {
      text = 'Setting up your secure verification session...';
    } else if (state is KycPolling) {
      text = 'Waiting for your verification result. This usually takes a few seconds.';
    } else if (state is KycAwaitingResult) {
      text = 'Your verification is being processed. We\'ll update your status automatically once complete.';
    } else if (state is KycVerified) {
      text = 'Your identity has been verified successfully.';
    } else if (state is KycFailed) {
      text = state.reason;
    } else {
      text = 'Please follow the instructions to verify your identity and unlock all features.';
    }

    return Text(
      text,
      textAlign: TextAlign.center,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: state is KycFailed
            ? Colors.red.shade400
            : theme.colorScheme.onSurface.withValues(alpha: 0.65),
        height: 1.5,
      ),
    );
  }

  Widget _buildAction(BuildContext context, KycState state) {
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
            child: const Text('Re-open Verification'),
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
              child: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Do This Later'),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}
