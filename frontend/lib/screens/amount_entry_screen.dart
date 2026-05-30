import 'package:flutter/material.dart';
import 'package:frontend/l10n/generated/app_localizations.dart';
import 'package:frontend/utils/emv_parser.dart';
import 'package:frontend/widgets/virtual_keypad.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/widgets/paycif_icon_container.dart';
import 'package:frontend/widgets/paycif_amount_text.dart';
import 'pay_screen.dart';
import '../theme/app_theme.dart';

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

  void _onNext() {
    final amount = double.tryParse(_controller.text) ?? 0.0;
    if (amount <= 0) return;

    setState(() => _isProcessing = true);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PayScreen(
          amount: amount,
          merchantName: _displayName, // Use looked up name
          promptPayId: widget.data.promptPayId,
          billerId: widget.data.billerId,
          reference1: widget.data.reference1,
          reference2: widget.data.reference2,
        ),
      ),
    ).then((result) {
      if (mounted) {
        setState(() => _isProcessing = false);
        if (result == true) {
          Navigator.pop(context, true);
        }
      }
    });
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Send Money'),
        centerTitle: true,
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
                          const SizedBox(height: 60),
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
          const SizedBox(width: 16),
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
                          color: Colors.grey[400],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Looking up...',
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
          const Icon(
            Icons.verified_rounded,
            color: Color(0xFF10B981),
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildCircleAvatar() {
    return const PaycifIconContainer(
      icon: Icons.person_outline_rounded,
      size: 28,
    );
  }

  Widget _buildAmountDisplay(bool isDark) {
    return Column(
      children: [
        Text(
          'Input Amount',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondaryColor(context),
                letterSpacing: 1.2,
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 16),
        PaycifAmountText(
          amount: double.tryParse(_controller.text) ?? 0.0,
          isLarge: true,
        ),
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
      height: 64,
      child: ElevatedButton(
        onPressed: (_isProcessing || !hasAmount) ? null : _onNext,
        child: _isProcessing
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text('Review Payment'),
      ),
    );
  }
}
