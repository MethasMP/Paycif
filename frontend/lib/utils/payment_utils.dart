import 'package:flutter/material.dart';

class PaymentUtils {
  /// Validates a credit card number using the Luhn Algorithm.
  static bool isValidLuhn(String cardNumber) {
    String cleanNumber = cardNumber.replaceAll(RegExp(r'\D'), '');
    if (cleanNumber.isEmpty) return false;

    int sum = 0;
    bool alternate = false;
    for (int i = cleanNumber.length - 1; i >= 0; i--) {
      int digit = int.parse(cleanNumber[i]);
      if (alternate) {
        digit *= 2;
        if (digit > 9) {
          digit -= 9;
        }
      }
      sum += digit;
      alternate = !alternate;
    }
    return sum % 10 == 0;
  }

  /// Detects the card provider based on the number pattern.
  static String getCardType(String cardNumber) {
    String input = cardNumber.replaceAll(RegExp(r'\D'), '');
    if (input.startsWith(RegExp(r'^4'))) {
      return 'Visa';
    } else if (input.startsWith(RegExp(r'^(5[1-5]|2[2-7])'))) {
      return 'Mastercard';
    } else if (input.startsWith(RegExp(r'^3[47]'))) {
      return 'Amex';
    } else if (input.startsWith(RegExp(r'^(352[89]|35[3-8][0-9])'))) {
      return 'JCB';
    } else if (input.startsWith(RegExp(r'^62'))) {
      return 'UnionPay';
    } else if (input.startsWith(RegExp(r'^6(?:011|5[0-9]{2})'))) {
      return 'Discover';
    }
    return 'Unknown';
  }

  /// Returns the corresponding icon for a card provider.
  static IconData getCardIcon(String cardType) {
    switch (cardType) {
      // Note: In a production app, these would be custom SVG icons
      // for Visa/Mastercard. Using standard Material icons as placeholders.
      case 'Visa':
        return Icons.credit_card;
      case 'Mastercard':
        return Icons.credit_card;
      case 'Amex':
        return Icons.credit_card;
      case 'JCB':
        return Icons.credit_card;
      case 'UnionPay':
        return Icons.credit_card;
      default:
        return Icons.credit_card;
    }
  }

  /// Returns the brand color for a card provider.
  static Color getCardColor(String cardType) {
    switch (cardType) {
      case 'Visa':
        return const Color(0xFF1A1F71);
      case 'Mastercard':
        return const Color(0xFFEB001B);
      case 'Amex':
        return const Color(0xFF016FD0);
      case 'UnionPay':
        return const Color(0xFFC00C1A);
      default:
        return const Color(0xFF1A1F71);
    }
  }
}
