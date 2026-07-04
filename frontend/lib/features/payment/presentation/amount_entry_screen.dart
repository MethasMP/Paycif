import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/l10n/generated/app_localizations.dart';
import 'package:frontend/core/utils/emv_parser.dart';
import 'package:frontend/core/widgets/virtual_keypad.dart';
import 'package:frontend/core/network/api_service.dart';
import 'package:frontend/core/widgets/paycif_icon_container.dart';
import 'package:frontend/core/widgets/paycif_amount_text.dart';
import 'package:frontend/features/payment/domain/entities/payment_breakdown.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/paycif_button.dart';

class AmountEntryScreen extends StatefulWidget {
  final EMFData data;

  const AmountEntryScreen({super.key, required this.data});

  @override
  State<AmountEntryScreen> createState() => _AmountEntryScreenState();
}

class _AmountEntryScreenState extends State<AmountEntryScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isProcessing = false;
  String? _lookupName; // Name from PromptPay lookup
  bool _isLookingUp = true;

  @override
  void initState() {
    super.initState();
    _lookupRecipientName();
  }

  Future<void> _lookupRecipientName() async {
    if (widget.data.promptPayId == null) {
      setState(() => _isLookingUp = false);
      return;
    }

  try {
      final api = ApiService();
      final name = await api.lookupPromptPayName(widget.data.promptPayId!);
      if (mounted) {
        setState(() {
          _lookupName = name;
          _isLookingUp = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLookingUp = false);
      }
    }
  }

  // Helper to get display name (prioritize lookup name)
  String get _displayName {
    if (_lookupName != null && _lookupName!.isNotEmpty) {
      return _lookupName!;
    }
    return widget.data.merchantName;
  }

  Future<void> _onNext() async {
    final amount = double.tryParse(_controller.text) ?? 0.0;
    if (amount <= 0) return;

    setState(() => _isProcessing = true);

    final result = await context.push('/pay', extra: {
      'amount': amount,
      'merchantName': _displayName,
      'promptPayId': widget.data.promptPayId,
      'billerId': widget.data.billerId,
      'reference1': widget.data.reference1,
      'reference2': widget.data.reference2,
    });
    if (mounted) {
      setState(() => _isProcessing = false);
      if (result == true) {
        Navigator.pop(context, true);
      }
    }
  }

  void _handleKeypadInput(String key) {
    if (_isProcessing) return;
    String currentText = _controller.text;

    if (key == '⌫') {
      if (currentText.isNotEmpty) {
        currentText = currentText.substring(0, currentText.length - 1);
      }
    } else if (key == '.') {
      if (!currentText.contains('.')) currentText += '.';
    } else {
      if (currentText == '0') {
        currentText = key;
      } else {
        currentText += key;
      }
    }

    if (currentText.contains('.')) {
      final parts = currentText.split('.');
      if (parts[1].length > 2) return;
    }
    if (currentText.replaceAll('.', '').length > 10) {
      return;
    }

    setState(() => _controller.text = currentText);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(PhosphorIcons.caretLeft, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(l10n.sendMoneyTitle),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          _buildRecipientCard(isDark),
                          SizedBox(height: 60),
                          _buildAmountDisplay(isDark),
                        ],
                      ),
                    ),
                  ),
                ),
                _buildInteractionZone(context, l10n, isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecipientCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.03),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      child: Row(
        children: [
          _buildCircleAvatar(),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Show loading or name
                if (_isLookingUp)
                  Row(
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.textSecondaryColor(context),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(context)!.amountLookingUpRecipient,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondaryColor(context),
                            ),
                      ),
                    ],
                  )
                else
                  Text(
                    _displayName,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AppTheme.textPrimaryColor(context),
                          fontWeight: FontWeight.w600,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                if (widget.data.promptPayId != null)
                  Text(
                    widget.data.promptPayId!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondaryColor(context),
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Icon(
            PhosphorIcons.sealCheck,
            color: AppTheme.successGreen,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildCircleAvatar() {
    return PaycifIconContainer(
      icon: PhosphorIcons.user,
      size: 28,
    );
  }

  Widget _buildAmountDisplay(bool isDark) {
    final amountTHB = double.tryParse(_controller.text) ?? 0.0;
    final breakdown = PaymentBreakdown(amountTHB: amountTHB);
    final totalUSD = breakdown.totalUSD;

    return Column(
      children: [
        Text(
          AppLocalizations.of(context)!.amountInputLabel,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondaryColor(context),
                letterSpacing: 1.2,
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 16),
        PaycifAmountText(
          amount: amountTHB,
          isLarge: true,
        ),
        if (amountTHB > 0) ...[
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.amountApproxUsdLabel(totalUSD.toStringAsFixed(2)),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondaryColor(context),
                ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.stateInfoSubtleDark : AppTheme.stateInfoSubtleLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  PhosphorIconsRegular.info,
                  size: 14,
                  color: AppTheme.stateInfo,
                ),
                const SizedBox(width: 6),
                Text(
                  AppLocalizations.of(context)!.amountRateLockedNotice(
                    (breakdown.convenienceFeePercentage * 100).toStringAsFixed(1),
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.stateInfo,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInteractionZone(
    BuildContext context,
    AppLocalizations l10n,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          VirtualKeypad(onKeyPressed: _handleKeypadInput),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: _buildActionBtn(l10n),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn(AppLocalizations l10n) {
    final bool hasAmount = (double.tryParse(_controller.text) ?? 0.0) > 0;

    return SizedBox(
      width: double.infinity,
      child: PaycifButton(
        text: l10n.payReviewTitle,
        isLoading: _isProcessing,
        onPressed: !hasAmount ? null : _onNext,
        variant: PaycifButtonVariant.primary,
        size: PaycifButtonSize.lg,
      ),
    );
  }
}
