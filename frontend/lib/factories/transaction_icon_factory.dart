import 'package:flutter/material.dart';

/// 🏭 [TransactionIconFactory]
/// Factory for determining the most appropriate icon for a transaction
/// based on its description and type (debit/credit).
class TransactionIconFactory {
  // Private constructor to prevent instantiation
  TransactionIconFactory._();

  /// Returns a smart icon based on transaction keywords and flow direction.
  static IconData create(String description, bool isDebit) {
    final lowerDesc = description.toLowerCase();

    // 1. Income / Inflow Logic
    if (!isDebit) {
      if (lowerDesc.contains('refund')) return Icons.refresh_rounded;
      return Icons.account_balance_wallet_rounded; // Default for Top Up
    }

    // 2. Spending Categories (Outflow)

    // Food & Dining
    if (lowerDesc.contains('food') ||
        lowerDesc.contains('restaurant') ||
        lowerDesc.contains('grab') ||
        lowerDesc.contains('eats') ||
        lowerDesc.contains('kfc') ||
        lowerDesc.contains('mcdonald')) {
      return Icons.restaurant_rounded;
    }

    // Shopping & Groceries
    if (lowerDesc.contains('mart') ||
        lowerDesc.contains('shop') ||
        lowerDesc.contains('store') ||
        lowerDesc.contains('7-11') ||
        lowerDesc.contains('market') ||
        lowerDesc.contains('big c') ||
        lowerDesc.contains('lotus')) {
      return Icons.shopping_bag_rounded;
    }

    // Transport & Travel
    if (lowerDesc.contains('transport') ||
        lowerDesc.contains('taxi') ||
        lowerDesc.contains('uber') ||
        lowerDesc.contains('bolt') ||
        lowerDesc.contains('bts') ||
        lowerDesc.contains('mrt')) {
      return Icons.local_taxi_rounded;
    }

    // Cafe & Coffee
    if (lowerDesc.contains('coffee') ||
        lowerDesc.contains('cafe') ||
        lowerDesc.contains('starbucks') ||
        lowerDesc.contains('amazon')) {
      return Icons.local_cafe_rounded;
    }

    // Entertainment
    if (lowerDesc.contains('movie') ||
        lowerDesc.contains('cinema') ||
        lowerDesc.contains('netflix') ||
        lowerDesc.contains('spotify') ||
        lowerDesc.contains('apple')) {
      return Icons.movie_rounded;
    }

    // Utilities & Bills
    if (lowerDesc.contains('bill') ||
        lowerDesc.contains('utility') ||
        lowerDesc.contains('water') ||
        lowerDesc.contains('electric') ||
        lowerDesc.contains('mea') ||
        lowerDesc.contains('pea') ||
        lowerDesc.contains('ais') ||
        lowerDesc.contains('true')) {
      return Icons.receipt_long_rounded;
    }

    // Transfers
    if (lowerDesc.contains('transfer') || lowerDesc.contains('sent')) {
      return Icons.swap_horiz_rounded;
    }

    // Default Spending Icon
    return Icons.shopping_bag_outlined;
  }
}
