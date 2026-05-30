import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/l10n/generated/app_localizations.dart';

import '../utils/pay_notify.dart';
import '../utils/payment_utils.dart';
import '../utils/error_translator.dart';
import '../theme/app_theme.dart';

class AddCardScreen extends StatefulWidget {
  const AddCardScreen({super.key});

  @override
  State<AddCardScreen> createState() => _AddCardScreenState();
}

class _AddCardScreenState extends State<AddCardScreen> {
  final _formKey = GlobalKey<FormState>();

  String cardNumber = '';
  String expiryDate = '';
  String cardHolderName = '';
  String cvvCode = '';
  bool isCvvFocused = false;
  bool _isLoading = false;
  String _loadingMessage = '';
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  final _cardNumberFocus = FocusNode();
  final _expiryFocus = FocusNode();
  final _cvvFocus = FocusNode();
  final _nameFocus = FocusNode();

  @override
  void dispose() {
    _cardNumberFocus.dispose();
    _expiryFocus.dispose();
    _cvvFocus.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          l10n.cardTitle,
          style: Theme.of(context).appBarTheme.titleTextStyle?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimaryColor(context),
          ) ?? Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimaryColor(context),
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            PhosphorIcons.arrowLeft,
            color: AppTheme.textPrimaryColor(context),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Card Preview
              _buildCardPreview(),

              SizedBox(height: 40),

              // Form
              Form(
                key: _formKey,
                autovalidateMode: _autovalidateMode,
                child: Column(
                  children: [
                    _buildTextField(
                      label: l10n.cardNumber,
                      hint: '0000 0000 0000 0000',
                      icon: PaymentUtils.getCardIcon(
                        PaymentUtils.getCardType(cardNumber),
                      ),
                      keyboardType: TextInputType.number,
                      focusNode: _cardNumberFocus,
                      inputFormatters: [_CardNumberFormatter()],
                      onChanged: (value) {
                        setState(() => cardNumber = value);
                        if (value.replaceAll(' ', '').length == 16) {
                          _expiryFocus.requestFocus();
                        }
                      },
                      validator: (value) {
                        final cleanNumber = value?.replaceAll(' ', '') ?? '';
                        if (cleanNumber.length < 16) {
                          return l10n.cardInvalidNumber;
                        }
                        if (!PaymentUtils.isValidLuhn(cleanNumber)) {
                          return l10n.cardInvalidLuhn;
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildTextField(
                            label: l10n.cardExpiry,
                            hint: l10n.cardExpiryHint,
                            icon: PhosphorIcons.calendar,
                            keyboardType: TextInputType.number,
                            focusNode: _expiryFocus,
                            inputFormatters: [_ExpiryDateFormatter()],
                            onChanged: (value) {
                              setState(() => expiryDate = value);
                              if (value.length == 5) {
                                _cvvFocus.requestFocus();
                              }
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return l10n.cardInvalidDate;
                              }
                              if (!RegExp(r'^\d{2}/\d{2}$').hasMatch(value)) {
                                return l10n.cardUseMMYY;
                              }
                              final parts = value.split('/');
                              final month = int.tryParse(parts[0]) ?? 0;
                              final year = int.tryParse(parts[1]) ?? 0;

                              if (month < 1 || month > 12) {
                                return l10n.cardInvalidMonth;
                              }

                              final now = DateTime.now();
                              final currentYear = now.year % 100;
                              final currentMonth = now.month;

                              if (year < currentYear) {
                                return l10n.cardExpired;
                              }
                              if (year == currentYear && month < currentMonth) {
                                return l10n.cardExpired;
                              }
                              return null;
                            },
                          ),
                        ),
                        SizedBox(width: 20),
                        Expanded(
                          child: _buildTextField(
                            label: l10n.cardCVV,
                            hint: '123',
                            icon: PhosphorIcons.lock,
                            keyboardType: TextInputType.number,
                            focusNode: _cvvFocus,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(3),
                            ],
                            onChanged: (value) {
                              setState(() => cvvCode = value);
                              if (value.length == 3) {
                                _nameFocus.requestFocus();
                              }
                            },
                            validator: (value) {
                              if (value == null || value.length < 3) {
                                return l10n.cardInvalidCVV;
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    _buildTextField(
                      label: l10n.cardHolder,
                      hint: l10n.cardHolderHint,
                      icon: PhosphorIcons.user,
                      focusNode: _nameFocus,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z ]')),
                        _UpperCaseTextFormatter(),
                      ],
                      onChanged: (value) =>
                          setState(() => cardHolderName = value),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return l10n.commonRequired;
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),

              SizedBox(height: 40),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () async {
                          if (_formKey.currentState!.validate()) {
                            setState(() {
                              _isLoading = true;
                              _loadingMessage = 'Securing card data...';
                            });
                            try {
                              throw Exception('Card binding is temporarily disabled. Moving to Coinflow.');
                            } catch (e) {
                              if (!mounted || !context.mounted) return;
                              setState(() {
                                _isLoading = false;
                                _loadingMessage = '';
                              });
                              PayNotify.error(
                                context,
                                ErrorTranslator.translate(l10n, e.toString()),
                              );
                            }
                          } else {
                            HapticFeedback.heavyImpact();
                            setState(() {
                              _autovalidateMode =
                                  AutovalidateMode.onUserInteraction;
                            });
                            PayNotify.error(
                              context,
                              l10n.commonValidationFailed,
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1F71),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 8,
                    shadowColor: const Color(0xFF1A1F71).withValues(alpha: 0.5),
                  ),
                  child: _isLoading
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              _loadingMessage,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          l10n.cardAddBtn,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardPreview() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            PaymentUtils.getCardColor(PaymentUtils.getCardType(cardNumber)),
            PaymentUtils.getCardColor(
              PaymentUtils.getCardType(cardNumber),
            ).withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: PaymentUtils.getCardColor(
              PaymentUtils.getCardType(cardNumber),
            ).withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                PaymentUtils.getCardType(cardNumber) == 'Unknown'
                    ? l10n.cardPreviewTitle
                    : PaymentUtils.getCardType(cardNumber),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
              Container(
                width: 45,
                height: 35,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFDAA520)],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            cardNumber.isEmpty ? '•••• •••• •••• ••••' : cardNumber,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontFamily: 'Courier',
              letterSpacing: 2,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.cardPreviewHolder,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    cardHolderName.isEmpty ? 'YOUR NAME' : cardHolderName,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    l10n.cardPreviewExpires,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    expiryDate.isEmpty ? 'MM/YY' : expiryDate,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    required Function(String) onChanged,
    String? Function(String?)? validator,
    FocusNode? focusNode,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondaryColor(context),
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextFormField(
            focusNode: focusNode,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            onChanged: onChanged,
            validator: validator,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryColor(context),
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.grey.withValues(alpha: 0.5),
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: Icon(
                icon,
                color: isDark ? Colors.white70 : const Color(0xFF1A1F71),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.transparent,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.selection.baseOffset == 0) return newValue;

    // Allow digits only and limit to 16 digits
    var text = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (text.length > 16) text = text.substring(0, 16);

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

class _ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.selection.baseOffset == 0) return newValue;

    // Allow digits only and limit to 4 digits (MMYY)
    var text = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (text.length > 4) text = text.substring(0, 4);

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

class _UpperCaseTextFormatter extends TextInputFormatter {
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
