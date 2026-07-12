import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:intl/intl.dart';

/// Signature amount display: Ink Primary, bold, tabular numerals.
/// Amounts are neutral financial facts — never tinted with the action color.
class PaycifAmountText extends StatelessWidget {
  final double amount;
  final String currencySymbol;
  final TextStyle? style;
  final bool isLarge;

  const PaycifAmountText({
    super.key,
    required this.amount,
    this.currencySymbol = 'THB ',
    this.style,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    final format = NumberFormat.currency(symbol: currencySymbol, decimalDigits: 2);
    final formattedAmount = format.format(amount);

    final baseStyle = style ??
        (isLarge
            ? AppTheme.amountTextStyle(context)
            : Theme.of(context).textTheme.headlineMedium);

    // Spell out the currency for screen readers so "THB 1,250.00" is not
    // announced as bare digits without monetary context.
    final spokenCurrency = currencySymbol.trim() == 'THB' || currencySymbol.trim() == '฿'
        ? 'Thai baht'
        : currencySymbol.trim();

    return Text(
      formattedAmount,
      semanticsLabel: '${amount.toStringAsFixed(2)} $spokenCurrency',
      style: isLarge && style == null
          ? baseStyle?.copyWith(color: AppTheme.textPrimaryColor(context))
          : baseStyle?.copyWith(
              color: AppTheme.textPrimaryColor(context),
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
    );
  }
}
