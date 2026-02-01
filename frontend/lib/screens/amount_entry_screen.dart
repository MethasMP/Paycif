import 'package:flutter/material.dart';
import 'package:frontend/l10n/generated/app_localizations.dart';
import 'package:frontend/utils/emv_parser.dart';
import 'package:frontend/widgets/virtual_keypad.dart';
import 'package:frontend/services/api_service.dart';
import 'pay_screen.dart';

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
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Send Money',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
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
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
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
                        style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                      ),
                    ],
                  )
                else
                  Text(
                    _displayName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                if (widget.data.promptPayId != null)
                  Text(
                    widget.data.promptPayId!,
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
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
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(
        Icons.person_outline_rounded,
        color: Colors.white,
        size: 28,
      ),
    );
  }

  Widget _buildAmountDisplay(bool isDark) {
    return Column(
      children: [
        Text(
          'Input Amount',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[500],
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '฿',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w300,
                color: isDark ? Colors.white38 : Colors.black26,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _controller.text.isEmpty ? '0.00' : _controller.text,
              style: TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.bold,
                color: _controller.text.isEmpty
                    ? (isDark ? Colors.white12 : Colors.black12)
                    : (isDark ? Colors.white : Colors.black87),
                letterSpacing: -2,
              ),
            ),
          ],
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
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
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

    return Container(
      width: double.infinity,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: hasAmount
            ? [
                BoxShadow(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: ElevatedButton(
        onPressed: (_isProcessing || !hasAmount) ? null : _onNext,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6366F1),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.withValues(alpha: 0.1),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: _isProcessing
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Review Payment',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }
}
