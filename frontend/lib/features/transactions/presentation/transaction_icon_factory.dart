import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
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
      if (lowerDesc.contains('refund')) return PhosphorIcons.arrowCounterClockwise;
      return PhosphorIcons.wallet; // Default for Top Up
    }

    // 2. Spending Categories (Outflow)

    // Food & Dining
    if (lowerDesc.contains('food') ||
        lowerDesc.contains('restaurant') ||
        lowerDesc.contains('grab') ||
        lowerDesc.contains('eats') ||
        lowerDesc.contains('kfc') ||
        lowerDesc.contains('mcdonald')) {
      return PhosphorIcons.forkKnife;
    }

    // Shopping & Groceries
    if (lowerDesc.contains('mart') ||
        lowerDesc.contains('shop') ||
        lowerDesc.contains('store') ||
        lowerDesc.contains('7-11') ||
        lowerDesc.contains('market') ||
        lowerDesc.contains('big c') ||
        lowerDesc.contains('lotus')) {
      return PhosphorIcons.shoppingBag;
    }

    // Transport & Travel
    if (lowerDesc.contains('transport') ||
        lowerDesc.contains('taxi') ||
        lowerDesc.contains('uber') ||
        lowerDesc.contains('bolt') ||
        lowerDesc.contains('bts') ||
        lowerDesc.contains('mrt')) {
      return PhosphorIcons.taxi;
    }

    // Cafe & Coffee
    if (lowerDesc.contains('coffee') ||
        lowerDesc.contains('cafe') ||
        lowerDesc.contains('starbucks') ||
        lowerDesc.contains('amazon')) {
      return PhosphorIcons.coffee;
    }

    // Entertainment
    if (lowerDesc.contains('movie') ||
        lowerDesc.contains('cinema') ||
        lowerDesc.contains('netflix') ||
        lowerDesc.contains('spotify') ||
        lowerDesc.contains('apple')) {
      return PhosphorIcons.filmStrip;
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
      return PhosphorIcons.receipt;
    }

    // Transfers
    if (lowerDesc.contains('transfer') || lowerDesc.contains('sent')) {
      return PhosphorIcons.arrowsLeftRight;
    }

    // Default Spending Icon
    return PhosphorIcons.shoppingBag;
  }
}
