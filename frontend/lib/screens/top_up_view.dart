import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
// import 'package:flutter_stripe/flutter_stripe.dart'; // Removed Stripe
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:frontend/l10n/generated/app_localizations.dart';
import '../models/saved_card.dart';
import '../services/api_service.dart';
import '../services/omise_service.dart';
import '../controllers/dashboard_controller.dart';
import '../controllers/payment_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import '../utils/payment_utils.dart';
import '../utils/error_translator.dart';
import '../utils/pay_notify.dart';
import '../utils/fee_calculator.dart';

class TopUpView extends StatefulWidget {
  const TopUpView({super.key});

  @override
  State<TopUpView> createState() => _TopUpViewState();
}

class _TopUpViewState extends State<TopUpView> {
  // ... (Keep existing State logic) ...
  final TextEditingController _amountController = TextEditingController();
  final ApiService _apiService = ApiService();
  final OmiseService _omiseService = OmiseService(); // New Service
  int? _selectedChipIndex;
  final bool _isLoading = false;
  final List<int> _smartAmounts = [500, 1000, 2000, 5000];
  final NumberFormat _currencyFormat = NumberFormat('#,###');
  final NumberFormat _decimalFormat = NumberFormat('#,##0.00');

  // FocusNodes for Custom Payment Sheet
  final FocusNode _cardNumberFocus = FocusNode();
  final FocusNode _expiryFocus = FocusNode();
  final FocusNode _cvvFocus = FocusNode();
  final FocusNode _nameFocus = FocusNode();

  // Controllers for Custom Payment Sheet
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController(); // MM/YY
  final _cvvController = TextEditingController();
  final _nameController = TextEditingController();

  double get _enteredAmount {
    final text = _amountController.text.replaceAll(',', '');
    return double.tryParse(text) ?? 0;
  }

  // Payment state is now managed globally by PaymentController

  @override
  void initState() {
    super.initState();
    _amountController.addListener(() {
      setState(() {
        if (_selectedChipIndex != null) {
          final chipAmount = _smartAmounts[_selectedChipIndex!];
          if (_enteredAmount != chipAmount.toDouble()) {
            _selectedChipIndex = null;
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _nameController.dispose();
    _cardNumberFocus.dispose();
    _expiryFocus.dispose();
    _cvvFocus.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _onChipSelected(int index) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedChipIndex = index;
      _amountController.text = _smartAmounts[index].toString();
    });
  }

  /// ─── ID NORMALIZATION ───
  /// Normalizes IDs for consistent comparison (e.g., ensuring card_ prefix)
  String _normalizeId(String id, String? type) {
    if (id == 'apple_pay') return id;
    if (type == 'card' && !id.startsWith('card_')) return 'card_$id';
    return id;
  }

  // New: Show Custom Opn Payment Sheet
  final _formKey = GlobalKey<FormState>(); // Add FormKey

  void _showOpnPaymentSheet() {
    // Local state for the sheet's autovalidation mode
    var sheetAutovalidateMode = AutovalidateMode.disabled;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        // Use StatefulBuilder to update sheet state
        builder: (context, setSheetState) {
          final l10n = AppLocalizations.of(context)!;
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              height: 600,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  // Handle Bar
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 20),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.lock_rounded,
                          size: 16,
                          color: Color(0xFF10B981),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.topUpTrustSecured,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: const Color(0xFF10B981),
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        autovalidateMode:
                            sheetAutovalidateMode, // Controlled by state
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.topUpPayAmount(
                                _decimalFormat.format(_enteredAmount),
                              ),
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Card Number
                            _buildField(
                              label: l10n.topUpCardNumber,
                              hint: '0000 0000 0000 0000',
                              controller: _cardNumberController,
                              icon: PaymentUtils.getCardIcon(
                                PaymentUtils.getCardType(
                                  _cardNumberController.text,
                                ),
                              ),
                              formatters: [CardNumberInputFormatter()],
                              onChanged: (value) {
                                setSheetState(() {}); // Update icon
                                if (value.replaceAll(' ', '').length == 16) {
                                  _expiryFocus.requestFocus();
                                }
                              },
                              focusNode: _cardNumberFocus,
                              validator: (value) {
                                final clean = value?.replaceAll(' ', '') ?? '';
                                if (clean.isEmpty) return l10n.commonRequired;
                                if (clean.length < 16) {
                                  return l10n.cardInvalidNumber;
                                }
                                if (!PaymentUtils.isValidLuhn(clean)) {
                                  return l10n.cardInvalidLuhn;
                                }
                                return null;
                              },
                              maxLength: 19,
                            ),
                            const SizedBox(height: 20),

                            // Row: Expiry + CVV
                            Row(
                              children: [
                                Expanded(
                                  child: _buildField(
                                    label: l10n.topUpExpiry,
                                    hint: l10n.cardExpiryHint,
                                    controller: _expiryController,
                                    icon: Icons.calendar_today_rounded,
                                    formatters: [ExpiryDateInputFormatter()],
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return l10n.commonRequired;
                                      }
                                      if (!RegExp(
                                        r'^\d{2}/\d{2}$',
                                      ).hasMatch(value)) {
                                        return l10n.cardInvalidDate;
                                      }

                                      final parts = value.split('/');
                                      final month = int.tryParse(parts[0]) ?? 0;
                                      final year = int.tryParse(parts[1]) ?? 0;

                                      if (month < 1 || month > 12) {
                                        return l10n.cardInvalidDate;
                                      }

                                      final now = DateTime.now();
                                      final currentYear = now.year % 100;
                                      final currentMonth = now.month;

                                      if (year < currentYear) {
                                        return l10n.cardInvalidDate;
                                      }
                                      if (year == currentYear &&
                                          month < currentMonth) {
                                        return l10n.cardInvalidDate;
                                      }

                                      return null;
                                    },
                                    maxLength: 5,
                                    focusNode: _expiryFocus,
                                    onChanged: (value) {
                                      if (value.length == 5) {
                                        _cvvFocus.requestFocus();
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildField(
                                    label: l10n.topUpCVV,
                                    hint: '123',
                                    controller: _cvvController,
                                    icon: Icons.security_rounded,
                                    obscure: true,
                                    formatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    maxLength: 3,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return l10n.commonRequired;
                                      }
                                      if (value.length < 3) {
                                        return l10n.cardInvalidCVV;
                                      }
                                      return null;
                                    },
                                    focusNode: _cvvFocus,
                                    onChanged: (value) {
                                      if (value.length == 3) {
                                        _nameFocus.requestFocus();
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Name
                            _buildField(
                              label: l10n.topUpNameOnCard,
                              hint: l10n.cardHolderHint,
                              controller: _nameController,
                              icon: Icons.person_rounded,
                              textCapitalization: TextCapitalization.characters,
                              formatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[a-zA-Z ]'),
                                ),
                                UpperCaseTextFormatter(),
                              ],
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return l10n.commonRequired;
                                }
                                return null;
                              },
                              focusNode: _nameFocus,
                            ),

                            const SizedBox(height: 40),

                            // Pay Button
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: () {
                                  if (_formKey.currentState!.validate()) {
                                    Navigator.pop(ctx); // Close sheet
                                    _handleOpnPayment(); // Process
                                  } else {
                                    HapticFeedback.heavyImpact(); // Feedback on error
                                    setSheetState(() {
                                      sheetAutovalidateMode =
                                          AutovalidateMode.onUserInteraction;
                                    });
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3949AB),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  l10n.topUpPayNow,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Test Card Hint (Simplified)
                            Center(
                              child: Text(
                                l10n.topUpTestCardHint,
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showMethodPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        final paymentController = Provider.of<PaymentController>(
          context,
          listen: false,
        );
        final cards = paymentController.savedCards;
        final prefId = paymentController.preferredMethodId;
        final prefType = paymentController.preferredMethodType;

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(ctx).scaffoldBackgroundColor,
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
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              if (Platform.isIOS)
                _buildPickerTile(
                  icon: Icons.apple,
                  title: l10n.applePay,
                  isSelected: prefType == 'apple_pay',
                  onTap: () {
                    paymentController.updatePreference(
                      'apple_pay',
                      'apple_pay',
                    );
                    Navigator.pop(ctx);
                  },
                ),
              ...cards.map(
                (card) => _buildPickerTile(
                  icon: Icons.credit_card_rounded,
                  title: '${card.brand} •••• ${card.lastDigits}',
                  isSelected:
                      prefType == 'card' &&
                      _normalizeId(prefId ?? '', 'card') ==
                          _normalizeId(card.id, 'card'),
                  onTap: () {
                    paymentController.updatePreference(card.id, 'card');
                    Navigator.pop(ctx);
                  },
                ),
              ),
              const Divider(),
              _buildPickerTile(
                icon: Icons.add_rounded,
                title: l10n.paymentAddMethod,
                isSelected: false,
                onTap: () {
                  Navigator.pop(ctx);
                  _showOpnPaymentSheet();
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPickerTile({
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

  Widget _buildField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    bool obscure = false,
    List<TextInputFormatter>? formatters,
    int? maxLength,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    FocusNode? focusNode,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Combine base formatters with length limit if needed
    List<TextInputFormatter> effectiveFormatters = formatters ?? [];
    if (maxLength != null) {
      effectiveFormatters.add(LengthLimitingTextInputFormatter(maxLength));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          inputFormatters: effectiveFormatters,
          textCapitalization: textCapitalization,
          validator: validator,
          onChanged: onChanged,
          focusNode: focusNode,
          // autovalidateMode: AutovalidateMode.onUserInteraction, // REMOVED
          keyboardType: TextInputType
              .text, // Changed from .number to .text to support Name
          decoration: InputDecoration(
            hintText: hint,
            counterText: '',
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B) : Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
            prefixIcon: Icon(icon, size: 20, color: Colors.grey),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleOpnPayment({
    bool useSaved = false,
    SavedCard? card,
    bool isApplePay = false,
  }) async {
    final l10n = AppLocalizations.of(context)!;

    // 💎 Calculate Fee Breakdown
    final feeBreakdown = FeeCalculator.calculateFromBaht(_enteredAmount);
    final walletAmountSatang = feeBreakdown.walletAmount.toBigInt().toInt();
    final chargeAmountSatang = feeBreakdown.chargeAmount.toBigInt().toInt();

    // 🚀 10x SPEED: Show Processing Overlay IMMEDIATELY (Zero Delay Start)
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => const _ProcessingOverlay(),
    );
    HapticFeedback.mediumImpact();

    // 🚀 10x SPEED: Parallel Session Check (Non-Blocking)
    // Don't await - let it run in background while we prepare the request
    ApiService.ensureSessionValid().ignore();

    try {
      String? token;

      if (!useSaved) {
        // Only create token for new cards (Saved cards skip this entirely)
        token = await _omiseService.createToken(
          name: _nameController.text,
          number: _cardNumberController.text,
          expiryMonth: _expiryController.text.split('/').first,
          expiryYear: '20${_expiryController.text.split('/').last}',
          securityCode: _cvvController.text,
        );
      }

      // 🚀 10x SPEED: Execute Charge with Fee-Included Amount
      // Charge: chargeAmountSatang (includes fee)
      // Wallet: walletAmountSatang (what user receives)
      await _apiService.executeOpnTopUp(
        amountSatang: chargeAmountSatang, // What to charge on card
        walletAmountSatang: walletAmountSatang, // What goes into wallet
        token: token,
        cardId: card?.id,
        isApplePay: isApplePay,
        referenceId: DateTime.now().millisecondsSinceEpoch.toString(),
      );

      // ✅ SUCCESS PATH: Instant UI Feedback
      if (mounted) {
        // 🚀 10x SPEED: Close overlay and show success IMMEDIATELY
        Navigator.of(
          context,
          rootNavigator: true,
        ).popUntil((route) => route is! DialogRoute);
        HapticFeedback.heavyImpact();
        _showSuccessDialog();

        // 🚀 10x SPEED: Optimistic Balance Update (Instant UI)
        // Update with WALLET amount (not charge amount) - this is what user sees
        // Capture controllers before async gap to fix use_build_context_synchronously
        final dashboardController = context.read<DashboardController>();
        final paymentController = context.read<PaymentController>();

        dashboardController.optimisticBalanceAdd(
          walletAmountSatang, // Use wallet amount, not charge amount
        );

        // 🚀 10x SPEED: Background Sync (Fire-and-Forget, Non-Blocking)
        // These run AFTER user sees success - they don't slow down perceived speed
        Future.microtask(() {
          dashboardController.init(); // Sync with DB in background
          if (card != null) {
            _apiService.updatePaymentPreference(card.id, 'card');
          } else if (isApplePay) {
            _apiService.updatePaymentPreference('apple_pay', 'apple_pay');
          }
          paymentController.fetchData(silent: true);
        });
      }
    } on FunctionException catch (e) {
      if (mounted) {
        Navigator.of(
          context,
          rootNavigator: true,
        ).popUntil((route) => route is! DialogRoute);
        if (e.status == 401) {
          _handleSessionExpired();
        } else {
          PayNotify.error(
            context,
            ErrorTranslator.translate(l10n, e.toString()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(
          context,
          rootNavigator: true,
        ).popUntil((route) => route is! DialogRoute);
        PayNotify.error(context, ErrorTranslator.translate(l10n, e.toString()));
      }
    }
  }

  void _handleSessionExpired() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.commonSessionExpired),
          content: Text(
            l10n.splashLoading, // Better than Log In
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Sign out and go to Login
                Supabase.instance.client.auth.signOut();
                Navigator.pop(ctx); // Close dialog
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
              child: Text(l10n.commonLogIn),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF10B981),
                size: 60,
              ),
              const SizedBox(height: 16),
              Text(l10n.commonSuccess),
              const SizedBox(height: 16), // Bottom padding for balance
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context); // Exit TopUp screen
              },
              child: Text(
                l10n.commonOk,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dashboardState = context.watch<DashboardController>().state;
    final currentBalance = (dashboardState.wallet?.balance ?? 0) / 100.0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.topUpTitle),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 16),
                  _buildBalanceCard(context, currentBalance, isDark, l10n),
                  const SizedBox(height: 40),
                  Text(
                    l10n.topUpAmountLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[500],
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildImmersiveAmount(context, isDark),
                  const SizedBox(height: 40),
                  _buildSmartSuggestions(context, isDark),
                ],
              ),
            ),
          ),
          _buildCustomKeypad(context, isDark),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: _buildPayButton(context, l10n),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(
    BuildContext context,
    double balance,
    bool isDark,
    AppLocalizations l10n,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.account_balance_wallet_rounded,
            color: const Color(0xFF3949AB).withValues(alpha: 0.8),
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            l10n.homeTotalBalance,
            style: TextStyle(
              color: isDark ? Colors.white60 : Colors.grey[600],
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '฿${_currencyFormat.format(balance)}',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImmersiveAmount(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final text = _amountController.text.isEmpty ? '0' : _amountController.text;

    // Calculate fee breakdown for display
    final feeBreakdown = FeeCalculator.calculateFromBaht(_enteredAmount);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '฿',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w300,
                color: const Color(0xFF3949AB),
                fontSize: 40,
              ),
            ),
            const SizedBox(width: 8),
            IntrinsicWidth(
              child: Text(
                text,
                style: theme.textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: text.length > 6 ? 48 : 64,
                  letterSpacing: -1,
                ),
              ),
            ),
          ],
        ),
        if (_enteredAmount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l10n.topUpChargeBreakdown(
                _decimalFormat.format(feeBreakdown.chargeAmountBaht),
              ),
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.grey[600],
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2),
          ),
      ],
    );
  }

  Widget _buildSmartSuggestions(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_smartAmounts.length, (index) {
          final amount = _smartAmounts[index];
          final isSelected = _selectedChipIndex == index;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              onTap: () => _onChipSelected(index),
              borderRadius: BorderRadius.circular(100),
              child: AnimatedContainer(
                duration: 200.ms,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF3949AB)
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.white),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF3949AB)
                        : (isDark ? Colors.white12 : Colors.grey[300]!),
                  ),
                ),
                child: Text(
                  '฿${_currencyFormat.format(amount)}',
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white70 : Colors.black87),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCustomKeypad(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          _buildKeypadRow(['1', '2', '3']),
          _buildKeypadRow(['4', '5', '6']),
          _buildKeypadRow(['7', '8', '9']),
          _buildKeypadRow(['.', '0', '⌫']),
        ],
      ),
    );
  }

  Widget _buildKeypadRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((key) => _buildKey(key)).toList(),
    );
  }

  Widget _buildKey(String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          _handleKeypadInput(label);
        },
        borderRadius: BorderRadius.circular(40),
        child: Container(
          width: 80,
          height: 60,
          alignment: Alignment.center,
          child: label == '⌫'
              ? Icon(
                  Icons.backspace_outlined,
                  color: isDark ? Colors.white70 : Colors.black54,
                  size: 20,
                )
              : Text(
                  label,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
        ),
      ),
    );
  }

  void _handleKeypadInput(String key) {
    String currentText = _amountController.text.replaceAll(',', '');

    if (key == '⌫') {
      if (currentText.isNotEmpty) {
        currentText = currentText.substring(0, currentText.length - 1);
      }
    } else if (key == '.') {
      if (!currentText.contains('.')) {
        currentText += '.';
      }
    } else {
      // Prevent leading zeros unless it's "0."
      if (currentText == '0') {
        currentText = key;
      } else {
        currentText += key;
      }
    }

    // Limit decimals to 2
    if (currentText.contains('.')) {
      final parts = currentText.split('.');
      if (parts[1].length > 2) return;
    }

    // Limit length
    if (currentText.length > 10) return;

    if (currentText.isEmpty) {
      _amountController.text = '';
      return;
    }

    // Format with commas for display
    final parts = currentText.split('.');
    final integerPart = parts[0];
    final decimalPart = parts.length > 1 ? '.${parts[1]}' : '';

    final doubleValue = double.tryParse(integerPart) ?? 0;
    final formattedInt = _currencyFormat.format(doubleValue);

    // If doubleValue is 0 but it's not actually empty (e.g., user typing "0."), handle it
    if (doubleValue == 0 && integerPart == '0') {
      _amountController.text = '0$decimalPart${key == '.' ? '.' : ''}';
    } else {
      // When user just typed '.', number format might strip it.
      _amountController.text = formattedInt + decimalPart;
    }

    // Logic for '.' is tricky with commas. Simplified for display.
    setState(() {});
  }

  Widget _buildPayButton(BuildContext context, AppLocalizations l10n) {
    final hasAmount = _enteredAmount > 0;

    return _buildPrimaryButton(
      context,
      label: l10n.commonNext,
      onPressed: hasAmount ? _showReviewSheet : null,
    );
  }

  void _showReviewSheet() {
    FocusScope.of(context).unfocus();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Consumer<PaymentController>(
        builder: (context, paymentController, child) {
          final l10n = AppLocalizations.of(context)!;
          final topUpAmount = _enteredAmount;

          // 💎 Calculate Fee Breakdown
          final feeBreakdown = FeeCalculator.calculateFromBaht(topUpAmount);

          final prefId = paymentController.preferredMethodId;
          final prefType = paymentController.preferredMethodType;
          final currentCards = paymentController.savedCards;

          // 💎 World-Class Selection Resolver (Match PaymentSettingsScreen)
          final isApplePayAvailable = (Platform.isIOS || Platform.isMacOS);

          final hasExactApplePay = prefType == 'apple_pay';
          final exactCardIndex = currentCards.indexWhere(
            (c) =>
                prefType == 'card' &&
                (_normalizeId(prefId ?? '', 'card') ==
                        _normalizeId(c.id, 'card') ||
                    prefId == c.id),
          );

          bool isApplePay;
          SavedCard? displayCard;

          if (hasExactApplePay) {
            isApplePay = true;
            displayCard = null;
          } else if (exactCardIndex != -1) {
            isApplePay = false;
            displayCard = currentCards[exactCardIndex];
          } else {
            // 🔄 Fallback Logic: Proactively pick the most logical method
            if (isApplePayAvailable) {
              isApplePay = true;
              displayCard = null;
            } else if (currentCards.isNotEmpty) {
              isApplePay = false;
              displayCard = currentCards.first;
            } else {
              isApplePay = false;
              displayCard = null;
            }
          }

          final theme = Theme.of(context);
          final isDark = theme.brightness == Brightness.dark;

          return Container(
            padding: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.commonConfirm,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // 💎 Fee Breakdown Section
                      _buildReviewRow(
                        // Amount to add to wallet
                        l10n.confirmAmount,
                        '฿${_decimalFormat.format(topUpAmount)}',
                      ),
                      const SizedBox(height: 12),
                      // 💎 Detailed Fee Breakdown (Granular Transparency)
                      _buildReviewRow(
                        // Transaction Fee (Total)
                        l10n.topUpProcessingFee(
                          feeBreakdown.effectiveFeePercent.toStringAsFixed(2),
                        ),
                        '+฿${_decimalFormat.format(feeBreakdown.totalFeeBaht)}',
                        isSubtle: true,
                      ),
                      const SizedBox(height: 8),
                      // Indented Breakdown
                      Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Column(
                          children: [
                            _buildReviewRow(
                              // Gateway Fee (e.g., 3.65%)
                              l10n.topUpFeeGateway(
                                (feeBreakdown.feeRate.toDouble() * 100)
                                    .toStringAsFixed(2),
                              ),
                              '฿${_decimalFormat.format(feeBreakdown.processingFeeBaht)}',
                              isSubtle: true,
                              isSmall: true, // Need to support smaller font
                            ),
                            const SizedBox(height: 4),
                            _buildReviewRow(
                              // VAT (e.g., 7%)
                              l10n.topUpFeeVat(
                                (feeBreakdown.vatRate.toDouble() * 100)
                                    .round()
                                    .toString(),
                              ),
                              '฿${_decimalFormat.format(feeBreakdown.vatBaht)}',
                              isSubtle: true,
                              isSmall: true,
                            ),
                            const SizedBox(height: 4),
                            _buildReviewRow(
                              // Platform Fee (Free)
                              l10n.topUpFeeNip,
                              l10n.topUpFeeFree,
                              isSubtle: true,
                              isSmall: true,
                              isGreen: true, // Highlight "Free"
                            ),
                          ],
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Divider(),
                      ),
                      // 💎 Total Charge (What card will be charged)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF3949AB).withValues(alpha: 0.15)
                              : const Color(0xFF3949AB).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(
                              0xFF3949AB,
                            ).withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.confirmTotalPayment,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  l10n.topUpChargeAmountLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '฿${_decimalFormat.format(feeBreakdown.chargeAmountBaht)}',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF3949AB),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          l10n.walletPaymentMethod,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () {
                          _showMethodPicker();
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isApplePay
                                    ? Icons.apple
                                    : (displayCard != null
                                          ? Icons.credit_card_rounded
                                          : Icons.add_card_rounded),
                                color: const Color(0xFF3949AB),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  isApplePay
                                      ? l10n.applePay
                                      : (displayCard != null
                                            ? '${displayCard.brand} •••• ${displayCard.lastDigits}'
                                            : l10n.paymentAddMethod),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      _buildPrimaryButton(
                        context,
                        label: (displayCard != null || isApplePay)
                            ? l10n.commonConfirm
                            : l10n.paymentAddMethod,
                        onPressed: () {
                          if (displayCard != null || isApplePay) {
                            Navigator.pop(context);
                            _handleOpnPayment(
                              useSaved: true,
                              card: displayCard,
                              isApplePay: isApplePay,
                            );
                          } else {
                            Navigator.pop(context);
                            _showOpnPaymentSheet();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildReviewRow(
    String label,
    String value, {
    bool isGreen = false,
    bool isSubtle = false,
    bool isSmall = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isSubtle ? Colors.grey[500] : Colors.grey[600],
            fontSize: isSmall ? 12 : (isSubtle ? 13 : 15),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: isSubtle ? FontWeight.w500 : FontWeight.w600,
            fontSize: isSmall ? 12 : (isSubtle ? 13 : 15),
            color: isGreen
                ? const Color(0xFF10B981)
                : isSubtle
                ? Colors.grey[600]
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton(
    BuildContext context, {
    required String label,
    VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3949AB),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}

class CurrencyInputFormatter extends TextInputFormatter {
  final NumberFormat _formatter = NumberFormat("#,##0.##");

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Prevent non-numeric usage except decimals
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // If result is just ".", ignore or handle
    if (newValue.text == '.') {
      return const TextEditingValue(
        text: '0.',
        selection: TextSelection.collapsed(offset: 2),
      );
    }

    // Try parsing
    String cleanText = newValue.text.replaceAll(',', '');

    // Handle multiple decimals - prevent adding a second '.'
    if (cleanText.indexOf('.') != cleanText.lastIndexOf('.')) {
      return oldValue;
    }

    // Check if it ends with decimal
    if (cleanText.endsWith('.')) {
      return newValue;
    }

    // Check decimal places limit (2)
    if (cleanText.contains('.')) {
      int decimalIndex = cleanText.indexOf('.');
      if (cleanText.length - decimalIndex > 3) {
        return oldValue;
      }
    }

    double? value = double.tryParse(cleanText);
    if (value == null) return oldValue;

    String newText = _formatter.format(value);

    // Restore decimal point if it was just typed
    if (cleanText.endsWith('.') && !newText.contains('.')) {
      newText += '.';
    } else if (cleanText.contains('.') && cleanText.endsWith('0')) {
      // Handle cases like "1.0" or "1.50" which default formatter might strip
      int decimalIndex = cleanText.indexOf('.');
      int decimals = cleanText.length - decimalIndex - 1;
      if (decimals > 0) {
        // For simplicity, just use the raw text if parsing gets complex during typing,
        // but here we want commas.
        // Let's rely on standard case unless complex.
        // Actually, simplest UX for top up is often just integers, but we allow decimals.
      }
    }

    // Simple robust approach for now:
    // If user is typing decimals, the formatter might be annoying.
    // Let's stick to allowing commas for integer part.

    List<String> parts = cleanText.split('.');
    String integerPart = parts[0];
    String decimalPart = parts.length > 1 ? '.${parts[1]}' : '';

    if (parts.length > 1 && parts[1].length > 2) {
      return oldValue; // Limit to 2 decimals
    }

    if (integerPart.isEmpty) integerPart = '0';

    final intVal = int.tryParse(integerPart) ?? 0;
    final formattedInt = NumberFormat("#,###").format(intVal);

    // If input ended with '.', append it
    if (newValue.text.endsWith('.') && !decimalPart.startsWith('.')) {
      decimalPart = '.';
    }

    String finalText = formattedInt + decimalPart;

    return TextEditingValue(
      text: finalText,
      selection: TextSelection.collapsed(offset: finalText.length),
    );
  }
}

// ============================================================================
// Custom Formatters
// ============================================================================

class CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.selection.baseOffset == 0) return newValue;

    // Allow digits only (strip spaces or others to re-format cleanly)
    final text = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      // Add space after every 4 digits, but not at the end
      if ((i + 1) % 4 == 0 && i != text.length - 1) {
        buffer.write(' ');
      }
    }

    final string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}

class ExpiryDateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.selection.baseOffset == 0) return newValue;

    // Allow digits only
    final text = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      // Add slash after 2nd digit
      if (i == 1 && i != text.length - 1) {
        buffer.write('/');
      }
    }

    final string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

/// 💎 World-Class Processing Overlay
/// Provides premium, focused feedback during financial transactions.
class _ProcessingOverlay extends StatelessWidget {
  const _ProcessingOverlay();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 40,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDark ? Colors.white : const Color(0xFF3949AB),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.confirmProcessing,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black54,
                decoration: TextDecoration.none, // Required for Dialog overlay
              ),
            ),
          ],
        ),
      ),
    );
  }
}
