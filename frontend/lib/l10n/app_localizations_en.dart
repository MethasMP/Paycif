// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'ZapPay';

  @override
  String get navHome => 'Home';

  @override
  String get navHistory => 'History';

  @override
  String get navPayment => 'Payment';

  @override
  String get navProfile => 'Profile';

  @override
  String get navScan => 'Scan';

  @override
  String get profileTitle => 'My Profile';

  @override
  String get passportLabel => 'PASSPORT';

  @override
  String get accountSecurity => 'ACCOUNT SECURITY';

  @override
  String get biometricLogin => 'Biometric Login';

  @override
  String get changePin => 'Change PIN';

  @override
  String get linkedDevices => 'Linked Devices';

  @override
  String get preferences => 'PREFERENCES';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get lightMode => 'Light Mode';

  @override
  String get language => 'Language';

  @override
  String get notifications => 'Notifications';

  @override
  String get support => 'SUPPORT';

  @override
  String get helpCenter => 'Help Center';

  @override
  String get contactSupport => 'Contact Support';

  @override
  String get signOut => 'Sign Out';

  @override
  String get version => 'Version';

  @override
  String get paymentStatus => 'Payment Status';

  @override
  String get paymentReady => 'READY';

  @override
  String get paymentReliable => 'reliable';

  @override
  String get paymentInstant => 'Instant';

  @override
  String get paymentNoFees => 'No Fees';

  @override
  String get paymentAddMethod => 'Add Payment Method';

  @override
  String get paymentEmptyTitle => 'No Payment Method Yet';

  @override
  String get paymentEmptyDesc =>
      'Once you add a payment method, we\'ll automatically select the best option for every transaction.';

  @override
  String get paymentChangeMethod => 'Change method (if needed)';

  @override
  String get paymentHideOptions => 'Hide other options';

  @override
  String get sheetAddPayment => 'Add Payment Method';

  @override
  String get sheetCreditCard => 'Credit or Debit Card';

  @override
  String get sheetCreditCardDesc => 'Visa, Mastercard, JCB, Amex';

  @override
  String get sheetTopUp => 'Top Up ZapPay Balance';

  @override
  String get sheetTopUpDesc => 'Via Bank Transfer or PromptPay';

  @override
  String get sheetDigitalWallet => 'Connect Digital Wallet';

  @override
  String get sheetDigitalWalletDesc => 'PayPal, Alipay, WeChat Pay';

  @override
  String get commonEnabled => 'Enabled';

  @override
  String get commonDisabled => 'Disabled';

  @override
  String get commonSuccess => 'Success';

  @override
  String get commonError => 'Error';
}
