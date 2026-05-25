import 'package:decimal/decimal.dart';

// ============================================================================
// Fee Calculator - Omise Payment Gateway Fee Calculation
// ============================================================================
// Calculates the total charge amount needed when user wants to receive
// a specific net amount in their wallet (Full Surcharge Model).
//
// Omise Fee Structure (Thailand):
// - Domestic Cards: 3.65% + VAT 7%
// - International Cards: 4.5% + VAT 7% (Future support)
//
// The calculator supports two layers:
// - Layer 1: Base fee calculated on the desired wallet amount
// - Layer 2: Additional fee incurred because Omise charges fees on the total
//            transaction amount (including the Layer 1 fee itself)
// ============================================================================

/// Fee calculation result containing all breakdown information
class FeeBreakdown {
  /// The amount user wants to receive in wallet (in minor units)
  final Decimal walletAmount;

  /// Layer 1: The base processing fee (on wallet amount)
  final Decimal processingFeeLayer1;

  /// Layer 1: VAT on the base processing fee
  final Decimal vatLayer1;

  /// Layer 2: Additional fee (fee on fee)
  final Decimal surchargeLayer2;

  /// Total fee = Layer1 + Layer2 (in minor units)
  final Decimal totalFee;

  /// Total charge = walletAmount + totalFee (in minor units)
  final Decimal chargeAmount;

  /// Fee rate used for calculation (e.g., 0.0365)
  final Decimal feeRate;

  /// VAT rate used (e.g., 0.07)
  final Decimal vatRate;

  const FeeBreakdown({
    required this.walletAmount,
    required this.processingFeeLayer1,
    required this.vatLayer1,
    required this.surchargeLayer2,
    required this.totalFee,
    required this.chargeAmount,
    required this.feeRate,
    required this.vatRate,
  });

  /// Get wallet amount in Baht (major units)
  double get walletAmountBaht => walletAmount.toDouble() / 100.0;

  /// Get Layer 1 processing fee in Baht
  double get processingFeeLayer1Baht => processingFeeLayer1.toDouble() / 100.0;

  /// Get Layer 1 VAT in Baht
  double get vatLayer1Baht => vatLayer1.toDouble() / 100.0;

  /// Get Layer 1 total in Baht
  double get feeLayer1Baht => processingFeeLayer1Baht + vatLayer1Baht;

  /// Get Surcharge Layer 2 in Baht
  double get surchargeLayer2Baht => surchargeLayer2.toDouble() / 100.0;

  /// Get total fee in Baht
  double get totalFeeBaht => totalFee.toDouble() / 100.0;

  /// Get charge amount in Baht
  double get chargeAmountBaht => chargeAmount.toDouble() / 100.0;

  /// Effective fee percentage (for display)
  double get effectiveFeePercent =>
      (feeRate * (Decimal.one + vatRate)).toDouble() * 100;

  // Legacy getters for backward compatibility
  Decimal get processingFee => processingFeeLayer1;
  Decimal get vat => vatLayer1;
  double get processingFeeBaht => processingFeeLayer1Baht;
  double get vatBaht => vatLayer1Baht;

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
  /// Returns [FeeBreakdown] containing all fee information including Layer 2 surcharge.
  ///
  /// This uses a two-layer surcharge model:
  /// - Layer 1: Fee on the wallet amount
  /// - Layer 2: Additional fee because Omise charges on the full transaction
  static FeeBreakdown calculate(
    Decimal walletAmountSatang, {
    bool isInternational = false,
  }) {
    if (walletAmountSatang <= Decimal.zero) {
      return FeeBreakdown(
        walletAmount: Decimal.zero,
        processingFeeLayer1: Decimal.zero,
        vatLayer1: Decimal.zero,
        surchargeLayer2: Decimal.zero,
        totalFee: Decimal.zero,
        chargeAmount: Decimal.zero,
        feeRate: domesticCardRate,
        vatRate: vatRate,
      );
    }

    final rate = isInternational ? internationalCardRate : domesticCardRate;

    // ═══════════════════════════════════════════════════════════════════════
    // LAYER 1: Base Fee (Simple calculation on wallet amount)
    // This is what Omise would charge if we only sent the wallet amount
    // ═══════════════════════════════════════════════════════════════════════
    final layer1Fee = (walletAmountSatang * rate).round();
    final layer1Vat = (layer1Fee * vatRate).round();
    final layer1Total = layer1Fee + layer1Vat;

    // ═══════════════════════════════════════════════════════════════════════
    // LAYER 2: Surcharge (Fee on Fee)
    // Because we need to charge the customer Layer1 fees, Omise will also
    // charge fees on that additional amount. We use iteration to find the
    // exact gross amount that nets to our target wallet amount.
    // ═══════════════════════════════════════════════════════════════════════

    // Calculate the true gross amount needed
    final effectiveRate = rate * (Decimal.one + vatRate);
    final divisor = Decimal.one - effectiveRate;

    // Use ceiling to ensure we always have enough after fees
    BigInt targetGross = (walletAmountSatang / divisor).ceil();

    // Verify and calculate actual fees at this gross amount
    final grossDec = Decimal.fromBigInt(targetGross);
    final actualFee = (grossDec * rate).round();
    final actualVat = (actualFee * vatRate).round();
    final actualTotalFee = actualFee + actualVat;
    final netAmount = grossDec - actualTotalFee;

    // If net is less than wallet (due to rounding), bump up by 1 satang
    Decimal finalGross = grossDec;
    Decimal finalTotalFee = actualTotalFee;
    if (netAmount < walletAmountSatang) {
      finalGross = Decimal.fromBigInt(targetGross + BigInt.one);
      final adjFee = (finalGross * rate).round();
      final adjVat = (adjFee * vatRate).round();
      finalTotalFee = adjFee + adjVat;
    }

    // Layer 2 Surcharge = Total actual fee - Layer 1 simple fee
    final surchargeLayer2 = finalTotalFee - layer1Total;

    return FeeBreakdown(
      walletAmount: walletAmountSatang,
      processingFeeLayer1: layer1Fee,
      vatLayer1: layer1Vat,
      surchargeLayer2: surchargeLayer2,
      totalFee: finalTotalFee,
      chargeAmount: finalGross,
      feeRate: rate,
      vatRate: vatRate,
    );
  }

  /// Calculate fee breakdown based on the TOTAL CHARGE amount (Inclusive Fee).
  /// This is used when the user enters the amount they want to pay/bill to card.
  ///
  /// [chargeAmountSatang] - The total amount to be charged to the card (Gross)
  static FeeBreakdown calculateFromCharge(
    Decimal chargeAmountSatang, {
    bool isInternational = false,
  }) {
    if (chargeAmountSatang <= Decimal.zero) {
      return calculate(Decimal.zero, isInternational: isInternational);
    }

    final rate = isInternational ? internationalCardRate : domesticCardRate;

    // Calculate actual fees on this gross amount
    final fee = (chargeAmountSatang * rate).round();
    final vat = (fee * vatRate).round();
    final totalFee = fee + vat;
    final walletAmount = chargeAmountSatang - totalFee;

    return FeeBreakdown(
      walletAmount: walletAmount,
      processingFeeLayer1: fee,
      vatLayer1: vat,
      surchargeLayer2: Decimal.zero, // No extra surcharge in inclusive model
      totalFee: totalFee,
      chargeAmount: chargeAmountSatang,
      feeRate: rate,
      vatRate: vatRate,
    );
  }

  /// Calculate from Baht amount (convenience method)
  /// Note: We keep this for backward compatibility but effectively
  /// most UIs should now move to calculateFromChargeBaht.
  static FeeBreakdown calculateFromBaht(
    double amountBaht, {
    bool isInternational = false,
    bool isChargeAmount =
        false, // 💎 Default: Input is Wallet Amount (Surcharge Model)
  }) {
    final satang = Decimal.parse((amountBaht * 100).toStringAsFixed(0));
    if (isChargeAmount) {
      return calculateFromCharge(satang, isInternational: isInternational);
    }
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
