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
import 'package:uuid/uuid.dart';
import '../features/security/domain/repositories/security_repository.dart';

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
  final List<int> _smartAmounts = [500, 1000, 2000, 3000]; // Max 3000/day
  final NumberFormat _currencyFormat = NumberFormat('#,###');
  final NumberFormat _decimalFormat = NumberFormat('#,##0.00');

  // Daily limit tracking
  double _dailyLimit = 3000.0; // 3,000 THB per day
  double _dailyUsed = 0.0;
  double _dailyRemaining = 3000.0;
  double _minPerTransaction = 500.0; // Min 500 THB per transaction
  bool _isLimitLoading = true;
  String? _limitError;

  // 🛡️ IDEMPOTENCY: Track the reference ID for the current payment attempt
  // If user retries due to error, we reuse this ID to prevent double charge.
  String? _pendingReferenceId;

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
    _fetchDailyLimits();
  }

  Future<void> _fetchDailyLimits() async {
    try {
      final limits = await _apiService.getDailyTopUpStatus();
      setState(() {
        _dailyLimit = (limits['max_daily_baht'] as num).toDouble();
        _dailyUsed = (limits['current_total_baht'] as num).toDouble();
        _dailyRemaining = (limits['remaining_limit_baht'] as num).toDouble();
        _minPerTransaction = (limits['min_per_transaction_baht'] as num)
            .toDouble();
        _isLimitLoading = false;
      });
    } catch (e) {
      setState(() {
        _limitError = 'Unable to load daily limits';
        _isLimitLoading = false;
      });
      debugPrint('❌ Failed to fetch daily limits: $e');
    }
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
      _pendingReferenceId = null; // New amount = New txn
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
    // Store repository reference before any async gaps
    final securityRepo = context.read<SecurityRepository>();

    // 💎 Calculate Fee Breakdown (Wallet-centric: User gets exactly what they typed)
    final feeBreakdown = FeeCalculator.calculateFromBaht(
      _enteredAmount,
      isChargeAmount: false,
    );
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

    // 🛡️ CRITICAL: Ensure session is fresh BEFORE any payment operation
    // This prevents race conditions where payment starts with stale/expired token
    await ApiService.ensureSessionValid();

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

      // 🛡️ SECURITY: Hardened Idempotency + Non-Repudiation (Signature)
      // 🛡️ IDEMPOTENCY: Reuse existing reference ID if retrying
      // This ensures we don't accidentally double-charge if the user presses Pay again
      // after a timeout or network error.
      _pendingReferenceId ??= const Uuid().v4();
      final referenceId = _pendingReferenceId!;

      Map<String, String>? signatureHeaders;

      try {
        signatureHeaders = await securityRepo.generateSignatureHeaders(
          referenceId,
        );
      } catch (e) {
        debugPrint('⚠️ [Signing] Failed to sign request: $e');
        // We continue for now, but in production this might be a Hard Reject
      }

      // 🚀 10x SPEED: Execute Charge with Fee-Included Amount
      // Charge: chargeAmountSatang (includes fee)
      // Wallet: walletAmountSatang (what user receives)
      try {
        await _apiService.executeOpnTopUp(
          amountSatang: chargeAmountSatang, // Total charge (Gross)
          walletAmountSatang: walletAmountSatang, // Actual top up amount (Net)
          token: token,
          cardId: card?.id,
          isApplePay: isApplePay,
          referenceId: referenceId,
          headers: signatureHeaders,
        );
      } catch (e) {
        // 🛡️ RECOVERY: Handle Key Mismatch (Integrity Check Failed)
        // This happens if the user reinstalled the app but server kept old key
        if (e.toString().contains('Request integrity check failed') ||
            e.toString().contains('Device not recognized')) {
          debugPrint(
            '⚠️ [Self-Healing] Integrity Check Failed. Re-binding device and retrying...',
          );

          // 1. Force Re-bind (Generate new keys & sync to server)
          await securityRepo.bindCurrentDevice();

          // 🛡️ FIX: Add delay to ensure DB replication/propagation completes
          // Supabase has minimal replication lag but edge functions may cache
          await Future.delayed(const Duration(milliseconds: 500));

          // 2. Re-sign the SAME reference_id with NEW keys
          final newHeaders = await securityRepo.generateSignatureHeaders(
            referenceId,
          );

          // 3. Retry the Top Up
          await _apiService.executeOpnTopUp(
            amountSatang: chargeAmountSatang,
            walletAmountSatang: walletAmountSatang,
            token: token,
            cardId: card?.id,
            isApplePay: isApplePay,
            referenceId: referenceId,
            headers: newHeaders,
          );
        } else {
          // Rethrow other errors (Balance insufficient, limit reached, etc.)
          rethrow;
        }
      }

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

        // 🛡️ Reset Idempotency Key for next distinct payment
        if (mounted) {
          setState(() {
            _pendingReferenceId = null;
            _amountController.clear(); // Reset input field
            _selectedChipIndex = null; // Reset chips
          });
        }
      }
    } on FunctionException catch (e) {
      if (mounted) {
        Navigator.of(
          context,
          rootNavigator: true,
        ).popUntil((route) => route is! DialogRoute);

        // 🛡️ FIX: Differentiate between Session Expired and Integrity Error
        final isIntegrityError =
            e.toString().contains('integrity check failed') ||
            e.toString().contains('Device not recognized');

        if (e.status == 401 && !isIntegrityError) {
          // Real Session Expired (JWT truly dead)
          _handleSessionExpired();
        } else if (isIntegrityError) {
          // Device Key Mismatch - Show friendly error, don't force logout
          debugPrint(
            '🔑 [TopUp] Integrity Error detected after all retries. Showing user message.',
          );
          PayNotify.error(
            context,
            'Security verification failed. Please try again or restart the app.',
          );
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
        title: Column(
          children: [
            Text(
              l10n.topUpTitle,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              '${l10n.homeTotalBalance} ฿${_currencyFormat.format(currentBalance)}',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.black54,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        centerTitle: true,
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
                  const SizedBox(height: 12),
                  // Direction 1: Unified Slim Limit Indicator
                  _buildSlimLimitBar(context, isDark),
                  const SizedBox(height: 48), // Comfortable spacing
                  // Amount Display (Removed "Amount to Add" Label)
                  _buildImmersiveAmount(context, isDark),
                  const SizedBox(height: 32), // Reduced from 40
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

  // Refactored: Slim, Unified Limit Bar (Direction 1)
  Widget _buildSlimLimitBar(BuildContext context, bool isDark) {
    if (_isLimitLoading) {
      return Center(
        child: SizedBox(
          width: 200,
          child: LinearProgressIndicator(
            minHeight: 2,
            backgroundColor: Colors.transparent,
            color: isDark ? Colors.white24 : Colors.grey[300],
          ),
        ),
      );
    }

    if (_limitError != null) return const SizedBox.shrink();

    final isLimitReached = _dailyRemaining <= 0;
    final progressPercent = (_dailyUsed / _dailyLimit).clamp(0.0, 1.0);
    final color = isLimitReached
        ? const Color(0xFFEF4444)
        : const Color(0xFF3949AB);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isLimitReached ? 'Daily Limit Reached' : 'Daily Limit',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white60 : Colors.grey[600],
              ),
            ),
            Text(
              '฿${_currencyFormat.format(_dailyRemaining)} / ฿${_currencyFormat.format(_dailyLimit)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white60 : Colors.grey[600],
                fontFamily: 'Monospace', // Aligns numbers nicely
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progressPercent,
            minHeight: 4, // Extremely slim
            backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildImmersiveAmount(BuildContext context, bool isDark) {
    final text = _amountController.text.isEmpty ? '0' : _amountController.text;

    // 🎯 TARGET: User wants this EXACT amount in their wallet
    final feeBreakdown = FeeCalculator.calculateFromBaht(
      _enteredAmount,
      isChargeAmount: false,
    );

    // Validation states
    final bool isBelowMinimum = _enteredAmount > 0 && _enteredAmount < 500;
    final bool isAboveLimit =
        _enteredAmount > _dailyRemaining && _dailyRemaining > 0;
    final bool isValid =
        _enteredAmount >= 500 && _enteredAmount <= _dailyRemaining;

    // Dynamic font size based on text length
    final double amountFontSize = text.length > 6 ? 48 : 56;
    final bool showFeeBreakdown = _enteredAmount > 0 && isValid;

    return Column(
      children: [
        // Amount Display with improved typography
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Currency symbol
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '฿',
                  style: TextStyle(
                    fontWeight: FontWeight.w400,
                    color: isValid || _enteredAmount == 0
                        ? const Color(0xFF1E40AF)
                        : isBelowMinimum
                        ? const Color(0xFFDC2626)
                        : const Color(0xFFF59E0B),
                    fontSize: 28,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Amount with animated value
              IntrinsicWidth(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOutCubic,
                  child: Text(
                    text,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: amountFontSize,
                      letterSpacing: -0.5,
                      height: 1.1,
                      color: isValid || _enteredAmount == 0
                          ? isDark
                                ? Colors.white
                                : Colors.black87
                          : isBelowMinimum
                          ? const Color(0xFFDC2626)
                          : const Color(0xFFB45309),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Fee breakdown - only show when valid
        if (showFeeBreakdown)
          Padding(
            padding: const EdgeInsets.only(top: 8), // Reduced from 12
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ), // Reduced from 12, 6
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : const Color(0xFFF5F5F7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 12,
                    color: isDark ? Colors.white54 : Colors.grey[500],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Total charge: ฿${_decimalFormat.format(feeBreakdown.chargeAmountBaht)}',
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.grey[600],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => _showFeeBreakdown(context, feeBreakdown),
                    child: Icon(
                      Icons.help_outline,
                      size: 12,
                      color: const Color(0xFF1E40AF),
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1),

        // Inline validation errors
        if (isBelowMinimum)
          _buildInlineError(
            icon: Icons.error_outline,
            message: 'Minimum top-up is ฿500',
            action: 'Set to ฿500',
            isError: true,
            onAction: () => _setAmount(500),
          ),

        if (isAboveLimit)
          _buildInlineError(
            icon: Icons.warning_amber_rounded,
            message:
                'Exceeds daily limit of ฿${_dailyLimit.toStringAsFixed(0)}',
            action: 'Set to max',
            isError: false,
            onAction: () => _setAmount(_dailyRemaining.toInt()),
          ),
      ],
    );
  }

  void _setAmount(int amount) {
    HapticFeedback.mediumImpact();
    _amountController.text = _currencyFormat.format(amount);
    _selectedChipIndex = _smartAmounts.indexOf(amount);
    if (_selectedChipIndex == -1) _selectedChipIndex = null;
    setState(() {
      _pendingReferenceId = null; // New amount = New txn
    });
  }

  Widget _buildInlineError({
    required IconData icon,
    required String message,
    required String action,
    required bool isError,
    required VoidCallback onAction,
  }) {
    final color = isError ? const Color(0xFFDC2626) : const Color(0xFFB45309);

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: color,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              action,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    ).animate().shake(duration: 400.ms, hz: 3);
  }

  void _showFeeBreakdown(BuildContext context, FeeBreakdown feeBreakdown) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.topUpFeeInfoTitle,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 20),

            // Row 1: Amount to Wallet
            _buildFeeRow(
              l10n.topUpAmountToWallet,
              '฿${feeBreakdown.walletAmountBaht.toStringAsFixed(2)}',
              icon: Icons.account_balance_wallet_rounded,
              iconColor: const Color(0xFF1E40AF),
              isDark: isDark,
            ),

            // Row 2: Paycif Service Fee
            _buildFeeRow(
              l10n.topUpFeePaysif,
              l10n.topUpFeeFree,
              icon: Icons.stars_rounded,
              iconColor: const Color(0xFF10B981),
              isDark: isDark,
              valueColor: const Color(0xFF10B981),
            ),

            // Row 3: Omise Processing Fee
            _buildFeeRow(
              l10n.topUpFeeGateway('3.65'),
              '฿${feeBreakdown.processingFeeLayer1Baht.toStringAsFixed(2)}',
              icon: Icons.credit_card_rounded,
              iconColor: Colors.orange,
              isDark: isDark,
            ),

            // Row 4: VAT
            _buildFeeRow(
              l10n.topUpVat,
              '฿${feeBreakdown.vatLayer1Baht.toStringAsFixed(2)}',
              icon: Icons.account_balance_rounded,
              iconColor: Colors.blueGrey,
              isDark: isDark,
            ),

            const Divider(height: 32, thickness: 1),

            // Row 5: Total Charge
            _buildFeeRow(
              l10n.topUpTotalCharge,
              '฿${feeBreakdown.chargeAmountBaht.toStringAsFixed(2)}',
              isDark: isDark,
              isTotal: true,
            ),

            const SizedBox(height: 24),

            // Trust Footer
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.verified_user_rounded,
                    size: 14,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Secured by Omise Gateway',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[400],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E40AF),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  l10n.commonGotIt,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeeRow(
    String label,
    String value, {
    required bool isDark,
    IconData? icon,
    Color? iconColor,
    Color? valueColor,
    bool isTotal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (iconColor ?? Colors.grey).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isTotal ? 17 : 15,
                fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
                color: isTotal
                    ? (isDark ? Colors.white : Colors.black87)
                    : (isDark ? Colors.white70 : Colors.black54),
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 18 : 15,
              fontWeight: isTotal ? FontWeight.w800 : FontWeight.w700,
              color:
                  valueColor ??
                  (isTotal
                      ? (isDark ? Colors.white : Colors.black)
                      : (isDark ? Colors.white : Colors.black87)),
              fontFamily: 'Monospace',
            ),
          ),
        ],
      ),
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
          // Disable chip if amount exceeds remaining daily limit
          final isDisabled = amount > _dailyRemaining;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              onTap: isDisabled ? null : () => _onChipSelected(index),
              borderRadius: BorderRadius.circular(100),
              child: AnimatedContainer(
                duration: 200.ms,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isDisabled
                      ? (isDark
                            ? Colors.white.withValues(alpha: 0.02)
                            : Colors.grey[100])
                      : isSelected
                      ? const Color(0xFF3949AB)
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.white),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: isDisabled
                        ? (isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.grey[300]!)
                        : isSelected
                        ? const Color(0xFF3949AB)
                        : (isDark ? Colors.white12 : Colors.grey[300]!),
                  ),
                ),
                child: Text(
                  '฿${_currencyFormat.format(amount)}',
                  style: TextStyle(
                    color: isDisabled
                        ? (isDark
                              ? Colors.white.withValues(alpha: 0.3)
                              : Colors.grey[400])
                        : isSelected
                        ? Colors.white
                        : (isDark ? Colors.white70 : Colors.black87),
                    fontWeight: isDisabled ? FontWeight.w400 : FontWeight.w600,
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
    final meetsMinimum = _enteredAmount >= _minPerTransaction;
    final withinLimit = _enteredAmount <= _dailyRemaining;
    final canProceed =
        hasAmount && meetsMinimum && withinLimit && !_isLimitLoading;

    return _buildPrimaryButton(
      context,
      label: l10n.commonNext,
      onPressed: canProceed ? _showReviewSheet : null,
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

          // 💎 Calculate Fee Breakdown (Wallet-centric: 500 entered = 500 received)
          final feeBreakdown = FeeCalculator.calculateFromBaht(
            topUpAmount,
            isChargeAmount: false,
          );

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
                      // 💎 HERO: What you get
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'You will receive',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '+฿${_decimalFormat.format(feeBreakdown.walletAmountBaht)}',
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF10B981),
                                letterSpacing: -1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // 💎 Breakdown
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : const Color(0xFFE9ECEF),
                          ),
                        ),
                        child: Column(
                          children: [
                            _buildReviewRow(
                              'Amount Added to Wallet',
                              '฿${_decimalFormat.format(feeBreakdown.walletAmountBaht)}',
                              isSubtle: false,
                            ),
                            const SizedBox(height: 12),
                            _buildReviewRow(
                              'Processing Fee (${feeBreakdown.effectiveFeePercent.toStringAsFixed(2)}%)',
                              '+฿${_decimalFormat.format(feeBreakdown.totalFeeBaht)}',
                              isSubtle: true,
                              isSmall: true,
                            ),
                            const Divider(height: 24),
                            _buildReviewRow(
                              'Total Deducted from Card',
                              '฿${_decimalFormat.format(feeBreakdown.chargeAmountBaht)}',
                              isSubtle: false,
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
