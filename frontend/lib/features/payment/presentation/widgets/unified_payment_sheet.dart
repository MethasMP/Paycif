import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/payment/presentation/logic/payment_cubit.dart';
import 'package:frontend/features/payment/presentation/logic/payment_state.dart';
import 'package:frontend/features/security/domain/repositories/security_repository.dart';
import 'package:frontend/features/payment/data/repositories/payment_repository_impl.dart';
import 'package:frontend/core/network/api_service.dart';
import 'package:frontend/core/models/exchange_rate_model.dart';
import 'package:frontend/core/l10n/generated/app_localizations.dart';
import 'package:frontend/core/utils/error_translator.dart';
import 'package:frontend/core/widgets/paycif_amount_text.dart';
import 'package:frontend/core/widgets/paycif_button.dart';
import 'package:frontend/core/widgets/paycif_icon_container.dart';
import 'package:frontend/core/widgets/app_icon.dart';
import 'package:frontend/core/widgets/virtual_keypad.dart';
import 'package:frontend/features/payment/presentation/widgets/swipe_to_pay_slider.dart';
import 'package:frontend/features/payment/data/qr_aggregator_service.dart';
import 'package:frontend/features/payment/domain/entities/payment_breakdown.dart';
import 'package:go_router/go_router.dart';

enum UnifiedSheetStep { amountInput, preview, polling, failure }

class UnifiedPaymentSheet extends StatefulWidget {
  final PaymentContext payContext;

  const UnifiedPaymentSheet({super.key, required this.payContext});

  @override
  State<UnifiedPaymentSheet> createState() => _UnifiedPaymentSheetState();
}

class _UnifiedPaymentSheetState extends State<UnifiedPaymentSheet> {
  late UnifiedSheetStep _step;
  final TextEditingController _amountController = TextEditingController();

  String? _lookupName;
  bool _isLookingUp = false;
  double _customAmount = 0.0;
  String _failureMessage = '';

  /// Live indicative FX rate for estimates while typing; null until fetched.
  /// Never a hardcoded constant — no rate is shown before a real one exists.
  double? _indicativeRate;

  @override
  void initState() {
    super.initState();
    final hasAmount = (widget.payContext.amount ?? 0) > 0;
    _step = hasAmount ? UnifiedSheetStep.preview : UnifiedSheetStep.amountInput;
    _customAmount = widget.payContext.amount ?? 0.0;
    _amountController.text = hasAmount ? _customAmount.toStringAsFixed(2) : '';
    _lookupRecipientName();
    _fetchIndicativeRate();
  }

  Future<void> _fetchIndicativeRate() async {
    try {
      final json = await ApiService().fetchExchangeRate('USD');
      final rate = ExchangeRate.fromJson(json).providerRate;
      if (mounted && rate != null && rate > 0) {
        setState(() => _indicativeRate = rate);
      }
    } catch (e) {
      debugPrint('⚠️ [PaymentSheet] Failed to fetch indicative rate: $e');
    }
  }

  Future<void> _lookupRecipientName() async {
    if (widget.payContext.accountId == null) return;
    setState(() => _isLookingUp = true);
    try {
      final api = ApiService();
      final name = await api.lookupPromptPayName(widget.payContext.accountId!);
      if (mounted) {
        setState(() {
          _lookupName = name;
          _isLookingUp = false;
        });
      }
    } catch (e) {
      debugPrint('⚠️ [PaymentSheet] Failed to look up recipient name: $e');
      if (mounted) setState(() => _isLookingUp = false);
    }
  }

  String get _displayName {
    if (_lookupName != null && _lookupName!.isNotEmpty) {
      return _lookupName!;
    }
    return widget.payContext.title;
  }

  PaymentReady? get _quote {
    try {
      final state = context.read<PaymentCubit>().state;
      if (state is PaymentReady) return state;
    } catch (_) {}
    return null;
  }

  /// Best available real rate: partner quote first, live indicative second.
  /// Null means "no real number yet" — the UI shows a pending state instead.
  double? get _exchangeRate => _quote?.exchangeRate ?? _indicativeRate;

  PaymentBreakdown? get _localBreakdown => _indicativeRate == null
      ? null
      : PaymentBreakdown(amountTHB: _customAmount, exchangeRate: _indicativeRate!);

  double? get _feeUSD => _quote?.feeUSD ?? _localBreakdown?.feeUSD;

  double? get _totalUSD => _quote?.totalUSD ?? _localBreakdown?.totalUSD;

  /// Payment may proceed only when a real total exists.
  bool get _hasRealTotal => _totalUSD != null;

  bool get _canGoBack {
    return _step == UnifiedSheetStep.preview && (widget.payContext.amount ?? 0) == 0;
  }

  void _handleBackPress() {
    if (_step == UnifiedSheetStep.preview) {
      setState(() => _step = UnifiedSheetStep.amountInput);
    }
  }

  void _handleKeypadInput(String key) {
    if (_step != UnifiedSheetStep.amountInput) return;
    String currentText = _amountController.text;

    if (key == '⌫') {
      if (currentText.isNotEmpty) {
        currentText = currentText.substring(0, currentText.length - 1);
      }
    } else if (key == '.') {
      if (currentText.isEmpty) {
        currentText = '0.';
      } else if (!currentText.contains('.')) {
        currentText += '.';
      }
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
    if (currentText.replaceAll('.', '').length > 10) return;

    setState(() {
      _amountController.text = currentText;
      _customAmount = double.tryParse(currentText) ?? 0.0;
    });
  }

  void _goToPreview(PaymentCubit cubit) {
    if (_customAmount <= 0) return;
    // Re-initialize Cubit with typed amount and fetch SQRIL Quotation
    cubit.initializeWithQR(
      qrString: widget.payContext.metadata['raw'] ?? '',
      amount: _customAmount,
    );
    setState(() {
      _step = UnifiedSheetStep.preview;
    });
  }

  bool _isInitiating = false;

  Future<void> _initiateOnRamp(PaymentCubit cubit) async {
    if (_isInitiating) return;
    _isInitiating = true;

    try {
      cubit.initiateOnRamp(
        promptPayId: widget.payContext.accountId ?? '',
        recipientName: _displayName,
        fiatCurrency: 'USD',
        billerId: widget.payContext.billerId,
        reference1: widget.payContext.reference1,
        reference2: widget.payContext.reference2,
      );
    } finally {
      _isInitiating = false;
    }
  }

  /// Opens the AlchemyPay checkout URL.
  /// iOS: in-app WebView (required for Apple Pay camera access)
  /// Android: external browser (required for Google Pay popup)
  Future<void> _launchCheckout(String webUrl, String intentId, PaymentCubit cubit) async {
    final uri = Uri.parse(webUrl);

    if (Platform.isIOS) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _AchCheckoutPage(uri: uri),
        ),
      );
      // User returned from WebView (via paycif:// redirect or close button)
      if (mounted) cubit.pollForCompletion(intentId);
    } else {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      // Android: start polling immediately since we can't intercept browser close
      if (mounted) cubit.pollForCompletion(intentId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BlocProvider(
      create: (context) => PaymentCubit(
        paymentRepository: PaymentRepositoryImpl(
          apiService: ApiService(),
          securityRepository: context.read<SecurityRepository>(),
        ),
      )..initializeWithQR(
          qrString: widget.payContext.metadata['raw'] ?? '',
          amount: _customAmount,
        ),
      child: BlocConsumer<PaymentCubit, PaymentState>(
        listener: (context, state) {
          if (state is PaymentSuccess) {
            Navigator.of(context).pop();
            context.push('/payment_success', extra: {
              'transactionId': state.transactionId,
              'amount': _customAmount,
              'totalUsd': _totalUSD,
              'recipientName': _displayName,
              'promptPayId': widget.payContext.accountId,
            });
          } else if (state is PaymentFailure) {
            setState(() {
              _step = UnifiedSheetStep.failure;
              _failureMessage = ErrorTranslator.translate(
                AppLocalizations.of(context)!,
                state.errorMessage,
              );
            });
          } else if (state is PaymentOnRampReady) {
            _launchCheckout(state.webUrl, state.intentId, context.read<PaymentCubit>());
          } else if (state is PaymentPolling) {
            setState(() => _step = UnifiedSheetStep.polling);
          }
        },
        builder: (context, state) {
          final cubit = context.read<PaymentCubit>();

          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              top: 12,
              left: 24,
              right: 24,
            ),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Navigation Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_canGoBack)
                      IconButton(
                        icon: AppIcon(
                          PhosphorIcons.caretLeft,
                          color: AppTheme.textSecondaryColor(context),
                          size: AppIconSize.sm,
                        ),
                        onPressed: _handleBackPress,
                      )
                    else if (_step == UnifiedSheetStep.amountInput ||
                        _step == UnifiedSheetStep.preview ||
                        _step == UnifiedSheetStep.polling)
                      // During polling this closes the sheet only — the payment
                      // keeps settling server-side and lands in History.
                      IconButton(
                        icon: AppIcon(
                          PhosphorIcons.x,
                          color: AppTheme.textSecondaryColor(context),
                          size: AppIconSize.sm,
                        ),
                        onPressed: () => Navigator.of(context).pop(false),
                      )
                    else
                      const SizedBox(width: 48, height: 48),

                    // Grab Handle
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkBorderHairline : AppTheme.lightBorderHairline,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    const SizedBox(width: 48, height: 48),
                  ],
                ),
                const SizedBox(height: 16),

                // Header / Recipient View (Shown in input and failure steps; inline in preview)
                if (_step == UnifiedSheetStep.amountInput || _step == UnifiedSheetStep.failure) ...[
                  _buildRecipientCard(isDark),
                  const SizedBox(height: 20),
                ],

                // Conditional Step Layouts
                _buildStepContent(context, cubit, isDark),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecipientCard(bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceSunken : AppTheme.lightSurfaceSunken,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorderHairline : AppTheme.lightBorderHairline,
        ),
      ),
      child: Row(
        children: [
          const PaycifIconContainer(icon: PhosphorIcons.storefront, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.successToLabel,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppTheme.textSecondaryColor(context),
                  ),
                ),
                const SizedBox(height: 2),
                if (_isLookingUp)
                  Row(
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primaryColor(context),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.amountLookingUpRecipient,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondaryColor(context),
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    _displayName,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryColor(context),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                if (widget.payContext.accountId != null)
                  Text(
                    widget.payContext.accountId!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondaryColor(context),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // Verified seal only when the PromptPay lookup actually returned a
          // name — never as unconditional decoration.
          if (_lookupName != null && _lookupName!.isNotEmpty)
            const AppIcon(PhosphorIcons.sealCheck, color: AppTheme.signalGreen, size: AppIconSize.sm),
        ],
      ),
    );
  }

  Widget _buildStepContent(BuildContext context, PaymentCubit cubit, bool isDark) {
    final state = cubit.state;
    if (state is PaymentLoading) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: CircularProgressIndicator(
          color: AppTheme.primaryColor(context),
        ),
      );
    }

    switch (_step) {
      case UnifiedSheetStep.amountInput:
        return _buildAmountInputView(cubit);
      case UnifiedSheetStep.preview:
        return _buildPreviewView(cubit, isDark);
      case UnifiedSheetStep.polling:
        return _buildPollingView();
      case UnifiedSheetStep.failure:
        return _buildFailureView(cubit);
    }
  }

  Widget _buildAmountInputView(PaymentCubit cubit) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final double amountTHB = _customAmount;

    return Column(
      children: [
        Text(
          l10n.amountInputLabel,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppTheme.textSecondaryColor(context),
          ),
        ),
        const SizedBox(height: 12),
        PaycifAmountText(amount: amountTHB, isLarge: true),
        if (amountTHB > 0 && _totalUSD != null) ...[
          const SizedBox(height: 8),
          Text(
            l10n.amountApproxUsdLabel(_totalUSD!.toStringAsFixed(2)),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondaryColor(context),
            ),
          ),
        ],
        const SizedBox(height: 16),
        VirtualKeypad(onKeyPressed: _handleKeypadInput),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: PaycifButton(
            text: l10n.payReviewTitle,
            onPressed: amountTHB > 0 ? () => _goToPreview(cubit) : null,
            variant: PaycifButtonVariant.primary,
            size: PaycifButtonSize.lg,
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewView(PaymentCubit cubit, bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final double amountTHB = _customAmount;
    // Platform-aware payment method label
    final String payMethodLabel = Platform.isIOS ? 'Apple Pay / Card' : 'Google Pay / Card';
    final IconData payMethodIcon = Platform.isIOS ? PhosphorIcons.appleLogo : PhosphorIcons.googleLogo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: PaycifAmountText(amount: amountTHB, isLarge: true)),
        const SizedBox(height: 4),
        Center(
          child: Text(
            _totalUSD != null
                ? l10n.amountApproxUsdLabel(_totalUSD!.toStringAsFixed(2))
                : l10n.sheetFetchingRate,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondaryColor(context),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // ─── Payment method (from) ───
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurfaceSunken : AppTheme.lightSurfaceSunken,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppTheme.darkBorderHairline : AppTheme.lightBorderHairline,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor(context).withValues(alpha: isDark ? 0.14 : 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: AppIcon(payMethodIcon, color: AppTheme.primaryColor(context), size: AppIconSize.sm),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.confirmPayWith,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: AppTheme.textSecondaryColor(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      payMethodLabel,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryColor(context),
                      ),
                    ),
                    Text(
                      l10n.paySecuredByPartner,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondaryColor(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Visual Connector Arrow
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurfaceSunken : AppTheme.lightSurfaceSunken,
              shape: BoxShape.circle,
            ),
            child: AppIcon(
              PhosphorIcons.arrowDown,
              size: AppIconSize.xs,
              color: AppTheme.textSecondaryColor(context),
            ),
          ),
        ),

        // ─── Recipient (to) ───
        _buildRecipientCard(isDark),
        const SizedBox(height: 16),

        // ─── Fee breakdown ───
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppTheme.darkBorderHairline : AppTheme.lightBorderHairline,
            ),
          ),
          child: Column(
            children: [
              _buildBreakdownRow(
                l10n.payFxRateLabel,
                _exchangeRate != null
                    ? '1 USD ≈ ${_exchangeRate!.toStringAsFixed(2)} THB'
                    : '—',
              ),
              const SizedBox(height: 8),
              _buildBreakdownRow(
                l10n.payAmountLabel,
                '฿${amountTHB.toStringAsFixed(2)}',
              ),
              const SizedBox(height: 8),
              _buildBreakdownRow(
                l10n.confirmFee,
                _feeUSD != null ? '\$${_feeUSD!.toStringAsFixed(2)} USD' : '—',
              ),
              if (widget.payContext.billerId != null ||
                  widget.payContext.reference1 != null ||
                  widget.payContext.reference2 != null) ...[
                const SizedBox(height: 8),
                if (widget.payContext.billerId != null) ...[
                  _buildBreakdownRow(l10n.payBillerIdLabel, widget.payContext.billerId!),
                  const SizedBox(height: 8),
                ],
                if (widget.payContext.reference1 != null) ...[
                  _buildBreakdownRow(l10n.payReference1Label, widget.payContext.reference1!),
                  const SizedBox(height: 8),
                ],
                if (widget.payContext.reference2 != null)
                  _buildBreakdownRow(l10n.payReference2Label, widget.payContext.reference2!),
              ],
              Divider(
                height: 24,
                thickness: 1,
                color: isDark ? AppTheme.darkBorderHairline : AppTheme.lightBorderHairline,
              ),
              _buildBreakdownRow(
                l10n.payTotalLabel,
                _totalUSD != null
                    ? '\$${_totalUSD!.toStringAsFixed(2)} USD'
                    : l10n.sheetFetchingRate,
                emphasized: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.payCrossBorderDisclaimer,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppTheme.textSecondaryColor(context),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 20),

        SwipeToPaySlider(
          onSwipeComplete: () => _initiateOnRamp(cubit),
          text: _hasRealTotal ? l10n.confirmSwipeToPay : l10n.sheetFetchingRate,
          enabled: _hasRealTotal,
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildBreakdownRow(String label, String value, {bool emphasized = false}) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: (emphasized ? theme.textTheme.bodyLarge : theme.textTheme.bodySmall)?.copyWith(
            color: emphasized
                ? AppTheme.textPrimaryColor(context)
                : AppTheme.textSecondaryColor(context),
            fontWeight: emphasized ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        Text(
          value,
          style: (emphasized ? theme.textTheme.bodyLarge : theme.textTheme.bodySmall)?.copyWith(
            color: AppTheme.textPrimaryColor(context),
            fontWeight: emphasized ? FontWeight.w700 : FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _buildPollingView() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor(context)),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.sheetConfirmingTitle,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.sheetConfirmingHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondaryColor(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFailureView(PaymentCubit cubit) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isPersonalQr = _failureMessage == 'PERSONAL_QR_NOT_SUPPORTED';
    final displayMessage = isPersonalQr ? l10n.sheetPersonalQrDesc : _failureMessage;
    final displayHeader = isPersonalQr ? l10n.sheetPersonalQrTitle : l10n.confirmPaymentFailed;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const AppIcon(PhosphorIcons.warningCircle, color: AppTheme.stateError, size: AppIconSize.xl),
          const SizedBox(height: 16),
          Text(
            displayHeader,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            displayMessage,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondaryColor(context),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: PaycifButton(
                  text: l10n.commonCancel,
                  onPressed: () => Navigator.of(context).pop(false),
                  variant: PaycifButtonVariant.secondary,
                  size: PaycifButtonSize.lg,
                ),
              ),
              if (!isPersonalQr) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: PaycifButton(
                    text: l10n.commonRetry,
                    onPressed: () {
                      setState(() {
                        _step = UnifiedSheetStep.preview;
                      });
                    },
                    variant: PaycifButtonVariant.primary,
                    size: PaycifButtonSize.lg,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// In-app WebView for AlchemyPay checkout (iOS only).
/// Intercepts paycif:// deep-link redirect to detect when the user completes payment.
class _AchCheckoutPage extends StatefulWidget {
  final Uri uri;

  const _AchCheckoutPage({required this.uri});

  @override
  State<_AchCheckoutPage> createState() => _AchCheckoutPageState();
}

class _AchCheckoutPageState extends State<_AchCheckoutPage> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _loading = true),
        onPageFinished: (_) => setState(() => _loading = false),
        onNavigationRequest: (req) {
          if (req.url.startsWith('paycif://')) {
            Navigator.of(context).pop(req.url);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(widget.uri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.sheetCheckoutTitle),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
