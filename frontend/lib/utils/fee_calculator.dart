import 'package:decimal/decimal.dart';

// ============================================================================
// Fee Calculator - Omise Payment Gateway Fee Calculation
// ============================================================================
// Calculates the total charge amount needed when user wants to receive
// a specific net amount in their wallet (Surcharge Model).
//
// Omise Fee Structure (Thailand):
// - Domestic Cards: 3.65% + VAT 7%
// - International Cards: 4.5% + VAT 7% (Future support)
// ============================================================================

/// Fee calculation result containing all breakdown information
class FeeBreakdown {
  /// The amount user wants to receive in wallet (in minor units)
  final Decimal walletAmount;

  /// The processing fee (in minor units)
  final Decimal processingFee;

  /// VAT on the processing fee (in minor units)
  final Decimal vat;

  /// Total fee = processingFee + VAT (in minor units)
  final Decimal totalFee;

  /// Total charge = walletAmount + totalFee (in minor units)
  final Decimal chargeAmount;

  /// Fee rate used for calculation (e.g., 0.0365)
  final Decimal feeRate;

  /// VAT rate used (e.g., 0.07)
  final Decimal vatRate;

  const FeeBreakdown({
    required this.walletAmount,
    required this.processingFee,
    required this.vat,
    required this.totalFee,
    required this.chargeAmount,
    required this.feeRate,
    required this.vatRate,
  });

  /// Get wallet amount in Baht (major units)
  double get walletAmountBaht => walletAmount.toDouble() / 100.0;

  /// Get processing fee in Baht
  double get processingFeeBaht => processingFee.toDouble() / 100.0;

  /// Get VAT in Baht
  double get vatBaht => vat.toDouble() / 100.0;

  /// Get total fee in Baht
  double get totalFeeBaht => totalFee.toDouble() / 100.0;

  /// Get charge amount in Baht
  double get chargeAmountBaht => chargeAmount.toDouble() / 100.0;

  /// Effective fee percentage (for display)
  double get effectiveFeePercent =>
      (feeRate * (Decimal.one + vatRate)).toDouble() * 100;

  @override
  String toString() {
    return 'FeeBreakdown(wallet: ฿${walletAmountBaht.toStringAsFixed(2)}, '
        'fee: ฿${totalFeeBaht.toStringAsFixed(2)}, '
        'charge: ฿${chargeAmountBaht.toStringAsFixed(2)})';
  }
}

/// Fee Calculator for Omise Payment Gateway
class FeeCalculator {
  // Omise Fee Rates (Thailand)
  static final Decimal domesticCardRate = Decimal.parse('0.0365'); // 3.65%
  static final Decimal internationalCardRate = Decimal.parse('0.045'); // 4.5%
  static final Decimal vatRate = Decimal.parse('0.07'); // 7% VAT

  // Minimum charge amount (to avoid micro-transactions)
  static final Decimal minimumChargeSatang = Decimal.fromInt(
    2000,
  ); // ฿20 minimum

  /// Calculate fee breakdown for a desired wallet amount.
  ///
  /// [walletAmountSatang] - The amount user wants to receive in wallet (in minor units)
  /// [isInternational] - Whether the card is international (higher fee)
  ///
  /// Returns [FeeBreakdown] containing all fee information.
  ///
  /// Formula: chargeAmount = walletAmount / (1 - (feeRate * (1 + vatRate)))
  static FeeBreakdown calculate(
    Decimal walletAmountSatang, {
    bool isInternational = false,
  }) {
    if (walletAmountSatang <= Decimal.zero) {
      return FeeBreakdown(
        walletAmount: Decimal.zero,
        processingFee: Decimal.zero,
        vat: Decimal.zero,
        totalFee: Decimal.zero,
        chargeAmount: Decimal.zero,
        feeRate: domesticCardRate,
        vatRate: vatRate,
      );
    }

    final feeRate = isInternational ? internationalCardRate : domesticCardRate;

    // Calculate effective rate including VAT
    // effectiveRate = feeRate * (1 + vatRate)
    // For domestic: 0.0365 * 1.07 = 0.039055
    final effectiveValue = Decimal.one - (feeRate * (Decimal.one + vatRate));

    // Reverse calculate charge amount
    // chargeAmount = walletAmount / (1 - effectiveRate)
    // Use rational to avoid precision loss during division then ceil
    final chargeAmountRat = walletAmountSatang / effectiveValue;
    final chargeAmountDec = Decimal.fromBigInt(chargeAmountRat.ceil());

    // Calculate the total fee (what Omise takes)
    final totalFee = chargeAmountDec - walletAmountSatang;

    // Break down fee into base fee and VAT
    // totalFee = baseFee + (baseFee * vatRate)
    // totalFee = baseFee * (1 + vatRate)
    // baseFee = totalFee / (1 + vatRate)
    final onePlusVat = Decimal.one + vatRate;
    final processingFeeRat = totalFee / onePlusVat;
    final processingFee = Decimal.fromBigInt(processingFeeRat.round());
    final vat = totalFee - processingFee;

    return FeeBreakdown(
      walletAmount: walletAmountSatang,
      processingFee: processingFee,
      vat: vat,
      totalFee: totalFee,
      chargeAmount: chargeAmountDec,
      feeRate: feeRate,
      vatRate: vatRate,
    );
  }

  /// Calculate from Baht amount (convenience method)
  static FeeBreakdown calculateFromBaht(
    double walletAmountBaht, {
    bool isInternational = false,
  }) {
    final satang = Decimal.parse((walletAmountBaht * 100).toStringAsFixed(0));
    return calculate(satang, isInternational: isInternational);
  }

  /// Format fee for display (e.g., "3.65% + VAT")
  static String formatFeeRateDisplay({bool isInternational = false}) {
    final rate = isInternational ? internationalCardRate : domesticCardRate;
    return '${(rate * Decimal.fromInt(100)).toString()}% + VAT';
  }

  /// Get effective fee percentage for display (e.g., "3.91%")
  static String formatEffectiveFeePercent({bool isInternational = false}) {
    final rate = isInternational ? internationalCardRate : domesticCardRate;
    final effective = rate * (Decimal.one + vatRate) * Decimal.fromInt(100);
    return '${effective.toStringAsFixed(2)}%';
  }
}
