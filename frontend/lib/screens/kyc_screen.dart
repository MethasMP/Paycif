import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/sumsub_kyc_cubit.dart';
import 'package:flutter_animate/flutter_animate.dart';

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

  void _launchSumsub(String token) async {
    debugPrint("Sumsub verification launched with mock token: $token");
    // Simulate SDK loading and user verification completion
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      context.read<SumsubKycCubit>().onSumsubCompleted();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: BlocConsumer<SumsubKycCubit, SumsubKycState>(
        listener: (context, state) {
          if (state is SumsubReady) {
            _launchSumsub(state.token);
          }
          if (state is SumsubCompleted) {
            Navigator.pop(context, true);
          }
        },
        builder: (context, state) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shield_outlined, color: Colors.blue, size: 80)
                    .animate(onPlay: (controller) => controller.repeat())
                    .shimmer(duration: 2.seconds),
                  const SizedBox(height: 32),
                  Text(
                    state is SumsubLoading ? 'Preparing Secure Link...' : 'Identity Verification',
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  if (state is SumsubFailed) ...[
                    Text(
                      state.reason,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => context.read<SumsubKycCubit>().initKyc(),
                      child: const Text('Retry Verification'),
                    ),
                  ] else ...[
                    const Text(
                      'Please follow the instructions on the next screen to verify your identity.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    const SizedBox(height: 48),
                    const CircularProgressIndicator(color: Colors.blue),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
