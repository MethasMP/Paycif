import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:local_auth/local_auth.dart';
import 'package:intl/intl.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:frontend/l10n/generated/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api_service.dart';
// Digital wallet button can be used for future payment method display

/// ─────────────────────────────────────────────────────────────────────────────
/// CONFIRM PAYMENT SCREEN - World-Class Payment Experience
/// ─────────────────────────────────────────────────────────────────────────────
/// A premium payment confirmation flow with:
/// - Dynamic payment method selection
/// - Biometric authentication
/// - Real-time quote display
/// - Slide-to-pay gesture
/// ─────────────────────────────────────────────────────────────────────────────

class ConfirmPaymentScreen extends StatefulWidget {
  final double amount;
  final String recipient;
  final bool isPromptPay;
  final String senderName;
  final String senderWalletId;
  final String? walletId;
  final VoidCallback onConfirmed;
  final bool isLockedAmount;
  final String? promptPayId;

  const ConfirmPaymentScreen({
    super.key,
    required this.amount,
    required this.recipient,
    this.isPromptPay = false,
    this.senderName = 'My Wallet',
    this.senderWalletId = '...8899',
    this.walletId,
    this.isLockedAmount = false,
    this.promptPayId,
    required this.onConfirmed,
  });

  @override
  State<ConfirmPaymentScreen> createState() => _ConfirmPaymentScreenState();
}

class _ConfirmPaymentScreenState extends State<ConfirmPaymentScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  final TextEditingController _amountController = TextEditingController();
  final ApiService _apiService = ApiService();

  double _slidePosition = 0.0;
  bool _isProcessing = false;
  double _enteredAmount = 0.0;

  // Payment Method Selection
  String _selectedPaymentMethod =
      'balance'; // balance, apple_pay, google_pay, card

  // Smart Quote State
  Map<String, dynamic>? _quote;
  bool _isLoadingQuote = false;

  @override
  void initState() {
    super.initState();
    if (widget.amount > 0) {
      _enteredAmount = widget.amount;
      _amountController.text = _formatNumber(widget.amount);
      _fetchQuote();
    }
    _amountController.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _onAmountChanged() {
    final text = _amountController.text.replaceAll(',', '');
    final val = double.tryParse(text) ?? 0.0;

    if (val != _enteredAmount) {
      setState(() => _enteredAmount = val);
      _debounceQuoteFetch();
    }
  }

  void _debounceQuoteFetch() {
    if (_enteredAmount > 0) {
      _fetchQuote();
    } else {
      setState(() => _quote = null);
    }
  }

  Future<void> _fetchQuote() async {
    setState(() => _isLoadingQuote = true);
    try {
      final quote = await _apiService.getQuote(_enteredAmount, 'THB');
      if (mounted) {
        setState(() {
          _quote = quote;
          _isLoadingQuote = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingQuote = false);
      }
    }
  }

  String _formatNumber(double value) {
    if (value == 0) return '';
    return NumberFormat('#,##0.##').format(value);
  }

  Future<void> _authenticate() async {
    if (_enteredAmount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter an amount')));
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final authenticated = await auth.authenticate(
        localizedReason: 'Confirm payment of ฿${_formatNumber(_enteredAmount)}',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );

      if (authenticated && mounted) {
        HapticFeedback.heavyImpact();
        await _executePayment();
      } else {
        setState(() {
          _slidePosition = 0.0;
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _slidePosition = 0.0;
          _isProcessing = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Authentication failed: $e')));
      }
    }
  }

  Future<void> _executePayment() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('Not authenticated');
      }

      String walletId = widget.walletId ?? '';
      if (walletId.isEmpty) {
        final walletData = await supabase
            .from('wallets')
            .select('id')
            .eq('profile_id', user.id)
            .single();
        walletId = walletData['id'] as String;
      }

      final targetType = widget.isPromptPay ? 'MOBILE' : 'EWALLET';
      final targetValue = widget.promptPayId ?? widget.recipient;

      final result = await _apiService.executePayout(
        walletId: walletId,
        amountSatang: _enteredAmount * 100,
        targetType: targetType,
        targetValue: targetValue,
        description: 'Payment to ${widget.recipient}',
      );

      if (result['success'] == true && mounted) {
        HapticFeedback.heavyImpact();
        _showReceipt(transactionId: result['transaction_id'] as String?);
      } else {
        throw Exception(result['error'] ?? 'Payment failed');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _slidePosition = 0.0;
          _isProcessing = false;
        });
        _showPaymentError(e.toString());
      }
    }
  }

  void _showPaymentError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment Failed'),
        content: Text(message.replaceAll('Exception: ', '')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showReceipt({String? transactionId}) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ReceiptScreen(
          amount: _enteredAmount,
          recipient: widget.recipient,
          senderName: widget.senderName,
          senderWalletId: widget.senderWalletId,
          transactionId: transactionId,
          onDone: widget.onConfirmed,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currencyFormat = NumberFormat('#,##0.00');

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.confirmTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            children: [
              // Amount Display
              _buildAmountSection(theme, isDark, currencyFormat),

              const SizedBox(height: 24),

              // Payment Method Selection
              _buildPaymentMethodSection(isDark),

              const SizedBox(height: 24),

              // Recipient Info
              _buildRecipientCard(isDark),

              const SizedBox(height: 24),

              // Transaction Summary
              if (_enteredAmount > 0) _buildSummaryCard(isDark, currencyFormat),

              const SizedBox(height: 32),

              // Slide to Pay
              _buildSlideToPayButton(),

              const SizedBox(height: 20),

              // Security Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.fingerprint, size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 8),
                  Text(
                    'Secured by Biometrics',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmountSection(
    ThemeData theme,
    bool isDark,
    NumberFormat currencyFormat,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF334155)]
              : [const Color(0xFF3949AB), const Color(0xFF5C6BC0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3949AB).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Amount to Pay',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          if (widget.isLockedAmount)
            Text(
              '฿${currencyFormat.format(_enteredAmount)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 42,
                fontWeight: FontWeight.bold,
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '฿',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                IntrinsicWidth(
                  child: TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: '0.00',
                      hintStyle: TextStyle(color: Colors.white38),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          if (widget.isLockedAmount) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_rounded, size: 12, color: Colors.white70),
                  SizedBox(width: 4),
                  Text(
                    'Amount set by merchant',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pay with',
          style: TextStyle(
            color: isDark ? Colors.white70 : const Color(0xFF64748B),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),

        // Payment Method Options
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildPaymentMethodChip(
              id: 'balance',
              label: 'Paysif Balance',
              icon: Icons.account_balance_wallet_rounded,
              color: const Color(0xFF10B981),
            ),
            _buildPaymentMethodChip(
              id: 'apple_pay',
              label: 'Apple Pay',
              icon: Icons.apple,
              color: Colors.black,
            ),
            _buildPaymentMethodChip(
              id: 'google_pay',
              label: 'Google Pay',
              icon: Icons.g_mobiledata_rounded,
              color: const Color(0xFF4285F4),
            ),
            _buildPaymentMethodChip(
              id: 'card',
              label: '•••• 4242',
              icon: Icons.credit_card_rounded,
              color: const Color(0xFF3949AB),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentMethodChip({
    required String id,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _selectedPaymentMethod == id;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedPaymentMethod = id);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.15)
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? color
                : (isDark ? Colors.white10 : Colors.grey[300]!),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? color
                  : (isDark ? Colors.white54 : Colors.grey[600]),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? color
                    : (isDark ? Colors.white : Colors.grey[700]),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Icon(Icons.check_circle_rounded, size: 16, color: color),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecipientCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.store_rounded, color: Color(0xFF10B981)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Paying to',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.recipient,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (widget.promptPayId != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1F71).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'PromptPay',
                style: TextStyle(
                  color: Color(0xFF1A1F71),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(bool isDark, NumberFormat currencyFormat) {
    // Extract fee from quote if available (Principal Engineer: Use data we fetch!)
    String feeDisplay = '฿0.00';
    String routeBadge = '';
    bool hasFee = false;

    if (_quote != null) {
      final routes = _quote!['routes'] as List<dynamic>? ?? [];
      if (routes.isNotEmpty) {
        final primaryRoute = routes.first as Map<String, dynamic>;
        final fee = primaryRoute['fee'];
        if (fee != null && fee != 0 && fee != '0') {
          feeDisplay =
              '฿${currencyFormat.format(double.tryParse(fee.toString()) ?? 0)}';
          hasFee = true;
        }
        routeBadge = primaryRoute['badge_text'] as String? ?? '';
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          // Smart Routing Badge (Principal Engineer Touch: Show we're optimizing!)
          if (routeBadge.isNotEmpty || _isLoadingQuote)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isLoadingQuote) ...[
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: isDark ? Colors.white38 : Colors.grey[400],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Finding best route...',
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.grey[500],
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.route_rounded,
                            size: 14,
                            color: Color(0xFF10B981),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            routeBadge.isNotEmpty
                                ? routeBadge
                                : 'Optimized Route',
                            style: const TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

          _buildSummaryRow(
            'Amount',
            '฿${currencyFormat.format(_enteredAmount)}',
          ),
          const SizedBox(height: 12),
          _buildSummaryRow('Fee', feeDisplay, isFree: !hasFee),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                '฿${currencyFormat.format(_enteredAmount)}',
                style: const TextStyle(
                  color: Color(0xFF3949AB),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isFree = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600])),
        Row(
          children: [
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isFree ? const Color(0xFF10B981) : null,
              ),
            ),
            if (isFree) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.flash_on_rounded,
                size: 14,
                color: Color(0xFF10B981),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildSlideToPayButton() {
    const double trackHeight = 64.0;
    const double thumbSize = 56.0;
    final double maxSlide =
        MediaQuery.of(context).size.width - 48 - thumbSize - 8;
    final bool canPay = _enteredAmount > 0;

    return Opacity(
      opacity: canPay ? 1.0 : 0.6,
      child: Container(
        height: trackHeight,
        decoration: BoxDecoration(
          color: _isProcessing
              ? const Color(0xFF10B981)
              : const Color(0xFF3949AB),
          borderRadius: BorderRadius.circular(32),
          boxShadow: canPay
              ? [
                  BoxShadow(
                    color: const Color(0xFF3949AB).withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                _isProcessing ? 'Processing...' : 'Swipe to Pay',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            if (!_isProcessing && canPay)
              Positioned(
                left: 4 + _slidePosition,
                top: 4,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      _slidePosition += details.delta.dx;
                      _slidePosition = _slidePosition.clamp(0.0, maxSlide);
                    });
                  },
                  onHorizontalDragEnd: (_) {
                    if (_slidePosition >= maxSlide * 0.9) {
                      HapticFeedback.heavyImpact();
                      _authenticate();
                    } else {
                      setState(() => _slidePosition = 0.0);
                    }
                  },
                  child: Container(
                    width: thumbSize,
                    height: thumbSize,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(2, 0),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Color(0xFF3949AB),
                    ),
                  ),
                ),
              ),
            if (_isProcessing)
              const Positioned(
                left: 4,
                top: 4,
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
/// RECEIPT SCREEN
/// ─────────────────────────────────────────────────────────────────────────────

class ReceiptScreen extends StatefulWidget {
  final double amount;
  final String recipient;
  final String senderName;
  final String senderWalletId;
  final String? transactionId;
  final VoidCallback onDone;

  const ReceiptScreen({
    super.key,
    required this.amount,
    required this.recipient,
    required this.senderName,
    required this.senderWalletId,
    this.transactionId,
    required this.onDone,
  });

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen>
    with TickerProviderStateMixin {
  final GlobalKey _receiptKey = GlobalKey();

  late AnimationController _successController;
  late AnimationController _contentController;

  late Animation<double> _checkScale;
  late Animation<double> _contentFade;
  late Animation<Offset> _contentSlide;

  String _refNumber = '';
  bool _autoSaved = false;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    final rand = Random().nextInt(9999).toString().padLeft(4, '0');
    _refNumber = 'ZAP${DateFormat('yyyyMMddHHmmss').format(now)}$rand';

    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _checkScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _successController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _contentFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOut),
    );

    _contentSlide = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _contentController, curve: Curves.easeOut),
        );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      HapticFeedback.heavyImpact();
      _successController.forward();
      await Future.delayed(const Duration(milliseconds: 400));
      _contentController.forward();

      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) _autoSaveReceipt();
    });
  }

  @override
  void dispose() {
    _successController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _autoSaveReceipt() async {
    try {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;

      final boundary =
          _receiptKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;

      ui.Image image = await boundary.toImage(pixelRatio: 1.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      await ImageGallerySaverPlus.saveImage(
        pngBytes,
        quality: 85,
        name: 'ZapPay_$_refNumber',
      );

      if (mounted) {
        setState(() => _autoSaved = true);
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      debugPrint('Auto-save error: $e');
    }
  }

  void _handleDone() {
    HapticFeedback.mediumImpact();
    widget.onDone();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat('#,##0.00');
    final now = DateTime.now();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A237E), Color(0xFF3949AB), Color(0xFF5C6BC0)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 1),
              _buildSuccessAnimation(),
              const SizedBox(height: 24),
              SlideTransition(
                position: _contentSlide,
                child: FadeTransition(
                  opacity: _contentFade,
                  child: const Text(
                    'Payment Successful',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SlideTransition(
                position: _contentSlide,
                child: FadeTransition(
                  opacity: _contentFade,
                  child: RepaintBoundary(
                    key: _receiptKey,
                    child: _buildReceiptCard(currencyFormat, now),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FadeTransition(
                opacity: _contentFade,
                child: AnimatedOpacity(
                  opacity: _autoSaved ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Receipt saved to Photos',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(flex: 1),
              SlideTransition(
                position: _contentSlide,
                child: FadeTransition(
                  opacity: _contentFade,
                  child: _buildDoneButton(),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessAnimation() {
    return AnimatedBuilder(
      animation: _successController,
      builder: (context, child) {
        return Transform.scale(
          scale: _checkScale.value,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 48,
            ),
          ),
        );
      },
    );
  }

  Widget _buildReceiptCard(NumberFormat currencyFormat, DateTime now) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 12,
            decoration: const BoxDecoration(
              color: Color(0xFF3949AB),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  '฿${currencyFormat.format(widget.amount)}',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 24),
                _buildReceiptRow(Icons.store_rounded, 'To', widget.recipient),
                _buildDivider(),
                _buildReceiptRow(
                  Icons.calendar_today_rounded,
                  'Date',
                  DateFormat('dd MMM yyyy, HH:mm').format(now),
                ),
                _buildDivider(),
                _buildReceiptRow(
                  Icons.tag_rounded,
                  'Ref',
                  _refNumber,
                  isSmall: true,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bolt_rounded, size: 16, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(
                      'ZapPay Official Receipt',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(
    IconData icon,
    String label,
    String value, {
    bool isSmall = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[400]),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 14)),
          const Spacer(),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
                fontSize: isSmall ? 12 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Divider(color: Colors.grey[200], height: 1),
    );
  }

  Widget _buildDoneButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _handleDone,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF3949AB),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Text(
            'Back to Home',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
