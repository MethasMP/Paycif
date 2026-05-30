import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:intl/intl.dart';

class PaycifAmountText extends StatelessWidget {
  final double amount;
  final String currencySymbol;
  final TextStyle? style;
  final bool isLarge;

  const PaycifAmountText({
    super.key,
    required this.amount,
    this.currencySymbol = 'THB ', // Default symbol is 'THB ' as per design.md
    this.style,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    final format = NumberFormat.currency(symbol: currencySymbol, decimalDigits: 2);
    final formattedAmount = format.format(amount);
    
    // Automatically adjust color based on theme - "Thai Money is Green"
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color amountColor = isDark ? const Color(0xFF2BBF9E) : AppTheme.primaryTeal;
    
    final baseStyle = style ?? (isLarge 
        ? Theme.of(context).textTheme.displayMedium 
        : Theme.of(context).textTheme.headlineMedium);

    return Text(
      formattedAmount,
      style: baseStyle?.copyWith(
        color: amountColor,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
