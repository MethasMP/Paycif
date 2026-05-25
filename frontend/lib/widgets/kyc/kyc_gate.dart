import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/api_service.dart';
import '../../cubit/sumsub_kyc_cubit.dart';
import '../../screens/kyc_screen.dart';
import '../../utils/pay_notify.dart';

class KycGate {
  static Future<bool> checkAndGate({
    required BuildContext context,
    required double amountBaht,
  }) async {
    try {
      final tier = await ApiService.getUserTier();

      if (tier == 'tier0') {
        if (amountBaht > 500) {
          if (context.mounted) {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BlocProvider(
                  create: (context) => SumsubKycCubit(),
                  child: const KycScreen(),
                ),
              ),
            );
            return result == true;
          }
        }
      } else if (tier == 'tier2') {
        if (amountBaht > 30000) {
          if (context.mounted) {
            PayNotify.error(context, 'Maximum transaction limit is ฿30,000');
          }
          return false;
        }
      }
      return true; // Limit okay or already verified
    } catch (e) {
      debugPrint('⚠️ [KycGate] Error: $e');
      if (context.mounted) {
        PayNotify.error(context, 'Security check failed. Please try again.');
      }
      return false;
    }
  }
}
