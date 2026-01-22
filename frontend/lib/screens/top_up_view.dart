import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:flutter_stripe/flutter_stripe.dart'; // Removed Stripe
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:frontend/l10n/generated/app_localizations.dart';
import '../models/saved_card.dart';
import '../services/api_service.dart';
import '../services/omise_service.dart';
import '../controllers/dashboard_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';

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
  bool _isLoading = false;
  final List<int> _smartAmounts = [500, 1000, 2000, 5000];
  final NumberFormat _currencyFormat = NumberFormat('#,###');

  // Controllers for Custom Payment Sheet
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController(); // MM/YY
  final _cvvController = TextEditingController();
  final _nameController = TextEditingController();

  double get _enteredAmount {
    final text = _amountController.text.replaceAll(',', '');
    return double.tryParse(text) ?? 0;
  }

  // Saved Card State
  List<SavedCard> _savedCards = [];
  SavedCard? _selectedCard;
  bool _checkingCard = true;
  // bool _hasSavedCard caused lint warning, actually we can derive it from _savedCards.isNotEmpty
  // keeping it for now if logic depends on it, but ideally remove it.
  // Let's rely on _savedCards.isNotEmpty.

  @override
  void initState() {
    super.initState();
    _checkSavedCard(); // Check for saved card
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

  Future<void> _checkSavedCard() async {
    try {
      final cards = await _apiService.getSavedCards();

      if (mounted) {
        setState(() {
          _savedCards = cards;
          _checkingCard = false;
          // Pre-select first card by default
          if (cards.isNotEmpty) {
            _selectedCard = cards.first;
          }
        });
      }
    } catch (e) {
      debugPrint('Error checking saved card: $e');
      if (mounted) setState(() => _checkingCard = false);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _onChipSelected(int index) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedChipIndex = index;
      _amountController.text = _smartAmounts[index].toString();
    });
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
                          'Secured by Omise',
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
                              'Pay ฿${_currencyFormat.format(_enteredAmount)}',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Card Number
                            _buildField(
                              label: 'Card Number',
                              hint: '0000 0000 0000 0000',
                              controller: _cardNumberController,
                              icon: Icons.credit_card_rounded,
                              formatters: [CardNumberInputFormatter()],
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Required';
                                }
                                if (value.replaceAll(' ', '').length < 16) {
                                  return 'Invalid card number';
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
                                    label: 'Expiry',
                                    hint: 'MM/YY',
                                    controller: _expiryController,
                                    icon: Icons.calendar_today_rounded,
                                    formatters: [ExpiryDateInputFormatter()],
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Required';
                                      }
                                      if (!RegExp(
                                        r'^\d{2}/\d{2}$',
                                      ).hasMatch(value)) {
                                        return 'Invalid format';
                                      }

                                      final parts = value.split('/');
                                      final month = int.tryParse(parts[0]) ?? 0;
                                      final year = int.tryParse(parts[1]) ?? 0;

                                      if (month < 1 || month > 12) {
                                        return 'Invalid month';
                                      }

                                      final now = DateTime.now();
                                      final currentYear = now.year % 100;
                                      final currentMonth = now.month;

                                      if (year < currentYear) {
                                        return 'Card expired';
                                      }
                                      if (year == currentYear &&
                                          month < currentMonth) {
                                        return 'Card expired';
                                      }

                                      return null;
                                    },
                                    maxLength: 5,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildField(
                                    label: 'CVV',
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
                                        return 'Required';
                                      }
                                      if (value.length < 3) {
                                        return 'Invalid CVV';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Name
                            _buildField(
                              label: 'Name on Card',
                              hint: 'JOHN DOE',
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
                                  return 'Required';
                                }
                                return null;
                              },
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
                                child: const Text(
                                  'Pay Now',
                                  style: TextStyle(
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
                                'Test Card: 4242 4242... (Any future date)',
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

  // Modified Build Pay Button for "Review" Flow
  Widget _buildPayButton(BuildContext context, AppLocalizations l10n) {
    final hasAmount = _enteredAmount > 0;

    if (_checkingCard) {
      return const Center(child: CircularProgressIndicator());
    }

    return _buildPrimaryButton(
      context,
      label: 'Next',
      icon: null, // No icon for Next button
      onPressed: hasAmount ? _showReviewSheet : null,
    );
  }

  // ... (Review Sheet code remains, skipping for brevity in replacement if not touched) ...

  Widget _buildPrimaryButton(
    BuildContext context, {
    required String label,
    IconData? icon, // Made optional
    VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3949AB),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
          shadowColor: const Color(0xFF3949AB).withValues(alpha: 0.4),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // New: Review Bottom Sheet
  void _showReviewSheet() {
    // Ensure keypad is closed
    FocusScope.of(context).unfocus();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final topUpAmount = _enteredAmount;
          final currentCards = _savedCards;
          // Default to first card if available and none selected, or keep selected
          SavedCard? displayCard = _selectedCard;
          if (displayCard == null && currentCards.isNotEmpty) {
            displayCard = currentCards.first;
            // Update parent state too to persist choice if sheet reopens
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _selectedCard = displayCard);
            });
          }

          final isDark = Theme.of(context).brightness == Brightness.dark;

          return Container(
            height: 500,
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                // Handle
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Review Top Up',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        // Amount Card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Amount',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                  Text(
                                    '฿${_currencyFormat.format(topUpAmount)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Fee',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                  const Text(
                                    '฿0.00',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Color(0xFF10B981),
                                    ),
                                  ),
                                ],
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12.0),
                                child: Divider(),
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  Text(
                                    '฿${_currencyFormat.format(topUpAmount)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 24,
                                      color: Color(0xFF3949AB),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Payment Method Selection
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Payment Method',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () {
                            // Close this sheet and open generic payment selection?
                            // For now, simple toggling or "Use different card" logic could live here.
                            // But based on request, we stick to "Pay with Card" button trigger logic
                            Navigator.pop(ctx);
                            _showOpnPaymentSheet(); // Or navigate to wallet management
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  displayCard != null
                                      ? Icons.credit_card
                                      : Icons.add_card,
                                  color: const Color(0xFF3949AB),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    displayCard != null
                                        ? '${displayCard.brand} •••• ${displayCard.lastDigits}'
                                        : 'Add / Select Card',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const Spacer(),

                        // Confirm Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              // Trigger payment
                              if (displayCard != null) {
                                _handleOpnPayment(useSaved: true);
                              } else {
                                // No saved card selected, open full Opn sheet
                                _showOpnPaymentSheet();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3949AB),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'Confirm & Pay',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleOpnPayment({bool useSaved = false}) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      String? token;

      if (!useSaved) {
        // 1. Tokenize Card (Client Side) ONLY if not using saved card
        token = await _omiseService.createToken(
          name: _nameController.text,
          number: _cardNumberController.text,
          expiryMonth: _expiryController.text.split('/').first,
          expiryYear: '20${_expiryController.text.split('/').last}',
          securityCode: _cvvController.text,
        );
      }

      // 2. Execute Charge via Backend (token is null if useSaved)
      await _apiService.executeOpnTopUp(
        amountSatang: (_enteredAmount * 100).toInt(),
        token: token,
        referenceId: DateTime.now().millisecondsSinceEpoch.toString(),
      );

      if (mounted) {
        HapticFeedback.heavyImpact();
        _showSuccessDialog();
        context.read<DashboardController>().init();

        // Save this as the preferred method (Transition from First-Time to Returning)
        _apiService.updatePaymentPreference('card', 'card');

        // Refresh saved card status (in case first time)
        _checkSavedCard();
      }
    } on FunctionException catch (e) {
      if (mounted) {
        if (e.status == 401) {
          _handleSessionExpired();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${l10n.commonError}: ${e.reasonPhrase ?? "Please try again"}',
              ),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleSessionExpired() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Session Expired'),
        content: const Text(
          'Your security session has ended. Please log in again to continue.',
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
            child: const Text('Log In'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF10B981),
              size: 60,
            ),
            SizedBox(height: 16),
            Text('Success!'),
          ],
        ),
        content: Text(
          'Your wallet has been topped up with ฿${_currencyFormat.format(_enteredAmount)}',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // Exit TopUp screen
            },
            child: const Text(
              'OK',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dashboardState = context.watch<DashboardController>().state;
    final currentBalance = (dashboardState.wallet?.balance ?? 0) / 100.0;
    final afterBalance = currentBalance + _enteredAmount;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.topUpTitle),
        // Style inherited from AppTheme.titleLarge via AppBarTheme.titleTextStyle
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBalanceCard(context, currentBalance, isDark, l10n),
            const SizedBox(height: 32),
            Text(
              l10n.topUpAmountLabel,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 12),
            _buildAmountInput(context, isDark),
            const SizedBox(height: 24),
            _buildSmartSuggestions(context, isDark),
            const SizedBox(height: 32),
            if (_enteredAmount > 0)
              _buildPreviewCard(context, afterBalance, isDark, l10n),
            const SizedBox(height: 32),
            _buildPayButton(context, l10n),
            const SizedBox(height: 16),
            _buildTrustBar(context, l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(
    BuildContext context,
    double balance,
    bool isDark,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF3949AB).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: Color(0xFF3949AB),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.homeTotalBalance,
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                '฿${_currencyFormat.format(balance)}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAmountInput(BuildContext context, bool isDark) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _enteredAmount > 0
              ? const Color(0xFF3949AB)
              : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
          width: _enteredAmount > 0 ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            '฿',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF3949AB),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                CurrencyInputFormatter(),
              ],
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: '0',
                hintStyle: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.grey.withValues(alpha: 0.3),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartSuggestions(BuildContext context, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(_smartAmounts.length, (index) {
        final amount = _smartAmounts[index];
        final isSelected = _selectedChipIndex == index;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: index == 0 ? 0 : 6,
              right: index == _smartAmounts.length - 1 ? 0 : 6,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _onChipSelected(index),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF3949AB)
                        : (isDark ? const Color(0xFF1E293B) : Colors.white),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF3949AB)
                          : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(
                                0xFF3949AB,
                              ).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '฿${_currencyFormat.format(amount)}',
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white : Colors.black87),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildPreviewCard(
    BuildContext context,
    double afterBalance,
    bool isDark,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      // ... (Keep existing styling) ...
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1A3A2F), const Color(0xFF0D2818)]
              : [const Color(0xFFD1FAE5), const Color(0xFFA7F3D0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: isDark
                    ? const Color(0xFF34D399)
                    : const Color(0xFF059669),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.topUpPreviewTitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark
                      ? const Color(0xFF34D399)
                      : const Color(0xFF047857),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '฿${_currencyFormat.format(afterBalance)}',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? const Color(0xFF10B981) : const Color(0xFF047857),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '+฿${_currencyFormat.format(_enteredAmount)} ${l10n.topUpPreviewSubtitle}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? Colors.white60 : const Color(0xFF065F46),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustBar(BuildContext context, AppLocalizations l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildTrustItem(Icons.lock_rounded, l10n.topUpTrustSecured),
        _buildTrustDivider(),
        _buildTrustItem(Icons.money_off_rounded, l10n.topUpTrustNoFees),
        _buildTrustDivider(),
        _buildTrustItem(Icons.bolt_rounded, l10n.topUpTrustInstant),
      ],
    );
  }

  // ... (Keep existing _buildTrustItem, _buildTrustDivider, CurrencyInputFormatter) ...

  Widget _buildTrustItem(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildTrustDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: Text('•', style: TextStyle(color: Colors.grey)),
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
