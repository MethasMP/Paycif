import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/payment/domain/entities/payment_breakdown.dart';

void main() {
  group('PaymentBreakdown Calculations Unit Test', () {
    test('Should calculate USD amount, fees and total correctly', () {
      const double amountTHB = 3645.0;
      const breakdown = PaymentBreakdown(
        amountTHB: amountTHB,
        exchangeRate: 36.45,
        convenienceFeePercentage: 0.035,
      );

      expect(breakdown.amountUSD, closeTo(100.0, 0.0001));
      expect(breakdown.feeUSD, closeTo(3.5, 0.0001));
      expect(breakdown.totalUSD, closeTo(103.5, 0.0001));
    });

    test('Should handle zero amount gracefully', () {
      const breakdown = PaymentBreakdown(amountTHB: 0.0);
      expect(breakdown.amountUSD, 0.0);
      expect(breakdown.feeUSD, 0.0);
      expect(breakdown.totalUSD, 0.0);
    });
  });
}
