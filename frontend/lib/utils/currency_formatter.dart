import 'package:intl/intl.dart';

/// Formats the integer balance (minor units) to a human-readable currency string.
///
/// [amount] is in smallest unit (e.g., satang).
/// [currencyCode] defaults to 'THB'.
String formatCurrency(int amount, [String currencyCode = 'THB']) {
  // Convert minor unit to major unit
  final double majorValue = amount / 100.0;

  // Format with commas and 2 decimal places
  final formatter = NumberFormat.currency(
    symbol: '', // We want "5,000.00 THB", not "$5,000.00"
    decimalDigits: 2,
    customPattern: '#,##0.00',
  );

  return formatter.format(majorValue);
}
