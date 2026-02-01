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
  /// The amount user wants to receive in wallet (in satang)
  final int walletAmount;

  /// The processing fee (in satang)
  final int processingFee;

  /// VAT on the processing fee (in satang)
  final int vat;

  /// Total fee = processingFee + VAT (in satang)
  final int totalFee;

  /// Total charge = walletAmount + totalFee (in satang)
  final int chargeAmount;

  /// Fee rate used for calculation (e.g., 0.0365)
  final double feeRate;

  /// VAT rate used (e.g., 0.07)
  final double vatRate;

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
  double get walletAmountBaht => walletAmount / 100.0;

  /// Get processing fee in Baht
  double get processingFeeBaht => processingFee / 100.0;

  /// Get VAT in Baht
  double get vatBaht => vat / 100.0;

  /// Get total fee in Baht
  double get totalFeeBaht => totalFee / 100.0;

  /// Get charge amount in Baht
  double get chargeAmountBaht => chargeAmount / 100.0;

  /// Effective fee percentage (for display)
  double get effectiveFeePercent => (feeRate * (1 + vatRate)) * 100;

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
  static const double domesticCardRate = 0.0365; // 3.65%
  static const double internationalCardRate = 0.045; // 4.5%
  static const double vatRate = 0.07; // 7% VAT

  // Minimum charge amount (to avoid micro-transactions)
  static const int minimumChargeSatang = 2000; // ฿20 minimum

  /// Calculate fee breakdown for a desired wallet amount.
  ///
  /// [walletAmountSatang] - The amount user wants to receive in wallet (in satang)
  /// [isInternational] - Whether the card is international (higher fee)
  ///
  /// Returns [FeeBreakdown] containing all fee information.
  ///
  /// Formula: chargeAmount = walletAmount / (1 - (feeRate * (1 + vatRate)))
  static FeeBreakdown calculate(
    int walletAmountSatang, {
    bool isInternational = false,
  }) {
    if (walletAmountSatang <= 0) {
      return const FeeBreakdown(
        walletAmount: 0,
        processingFee: 0,
        vat: 0,
        totalFee: 0,
        chargeAmount: 0,
        feeRate: domesticCardRate,
        vatRate: vatRate,
      );
    }

    final feeRate = isInternational ? internationalCardRate : domesticCardRate;

    // Calculate effective rate including VAT
    // effectiveRate = feeRate * (1 + vatRate)
    // For domestic: 0.0365 * 1.07 = 0.039055
    final effectiveRate = feeRate * (1 + vatRate);

    // Reverse calculate charge amount
    // chargeAmount = walletAmount / (1 - effectiveRate)
    final chargeAmountDouble = walletAmountSatang / (1 - effectiveRate);
    final chargeAmount = chargeAmountDouble
        .ceil(); // Round up to ensure full amount

    // Calculate the total fee (what Omise takes)
    final totalFee = chargeAmount - walletAmountSatang;

    // Break down fee into base fee and VAT
    // totalFee = baseFee + (baseFee * vatRate)
    // totalFee = baseFee * (1 + vatRate)
    // baseFee = totalFee / (1 + vatRate)
    final processingFeeDouble = totalFee / (1 + vatRate);
    final processingFee = processingFeeDouble.round();
    final vat = totalFee - processingFee;

    return FeeBreakdown(
      walletAmount: walletAmountSatang,
      processingFee: processingFee,
      vat: vat,
      totalFee: totalFee,
      chargeAmount: chargeAmount,
      feeRate: feeRate,
      vatRate: vatRate,
    );
  }

  /// Calculate from Baht amount (convenience method)
  static FeeBreakdown calculateFromBaht(
    double walletAmountBaht, {
    bool isInternational = false,
  }) {
    final satang = (walletAmountBaht * 100).round();
    return calculate(satang, isInternational: isInternational);
  }

  /// Format fee for display (e.g., "3.65% + VAT")
  static String formatFeeRateDisplay({bool isInternational = false}) {
    final rate = isInternational ? internationalCardRate : domesticCardRate;
    return '${(rate * 100).toStringAsFixed(2)}% + VAT';
  }

  /// Get effective fee percentage for display (e.g., "3.91%")
  static String formatEffectiveFeePercent({bool isInternational = false}) {
    final rate = isInternational ? internationalCardRate : domesticCardRate;
    final effective = rate * (1 + vatRate) * 100;
    return '${effective.toStringAsFixed(2)}%';
  }
}
