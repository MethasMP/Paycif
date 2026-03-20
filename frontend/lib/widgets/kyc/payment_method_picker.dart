import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/saved_card.dart';
import '../../l10n/generated/app_localizations.dart';

class PaymentMethodPicker extends StatelessWidget {
  final String? preferredMethodId;
  final String? preferredMethodType;
  final List<SavedCard> savedCards;
  final Function(String id, String type) onMethodSelected;
  final VoidCallback onAddMethod;

  const PaymentMethodPicker({
    super.key,
    required this.preferredMethodId,
    required this.preferredMethodType,
    required this.savedCards,
    required this.onMethodSelected,
    required this.onAddMethod,
  });

  String _normalizeId(String id, String? type) {
    if (id == 'apple_pay') return id;
    if (type == 'card' && !id.startsWith('card_')) return 'card_$id';
    return id;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Text(
                  l10n.walletPaymentMethod,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          if (Platform.isIOS)
            _buildPickerTile(
              context: context,
              icon: Icons.apple,
              title: l10n.applePay,
              isSelected: preferredMethodType == 'apple_pay',
              onTap: () {
                onMethodSelected('apple_pay', 'apple_pay');
                Navigator.pop(context);
              },
            ),
          ...savedCards.map(
            (card) => _buildPickerTile(
              context: context,
              icon: Icons.credit_card_rounded,
              title: '${card.brand} •••• ${card.lastDigits}',
              isSelected: preferredMethodType == 'card' &&
                  _normalizeId(preferredMethodId ?? '', 'card') ==
                      _normalizeId(card.id, 'card'),
              onTap: () {
                onMethodSelected(card.id, 'card');
                Navigator.pop(context);
              },
            ),
          ),
          const Divider(),
          _buildPickerTile(
            context: context,
            icon: Icons.add_rounded,
            title: l10n.paymentAddMethod,
            isSelected: false,
            onTap: () {
              Navigator.pop(context);
              onAddMethod();
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildPickerTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? const Color(0xFF10B981) : Colors.grey,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? const Color(0xFF10B981) : null,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981))
          : null,
      onTap: onTap,
    );
  }
}
