// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Paysif';

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
  String get sheetTopUp => 'Top Up Paysif Balance';

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

  @override
  String get commonToday => 'Today';

  @override
  String get commonYesterday => 'Yesterday';

  @override
  String get commonApply => 'Apply';

  @override
  String get commonSave => 'Save';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonUpload => 'Upload';

  @override
  String get commonHelp => 'Help';

  @override
  String get commonGotIt => 'Got it!';

  @override
  String get commonRequired => 'Required';

  @override
  String get commonInvalid => 'Invalid';

  @override
  String get homeTopUp => 'Top Up';

  @override
  String get homeInfo => 'Info';

  @override
  String get homeMore => 'More';

  @override
  String get homeTotalBalance => 'Total Balance';

  @override
  String get homeShow => 'Show';

  @override
  String get homeHide => 'Hide';

  @override
  String get homeWorldMember => 'WORLD MEMBER';

  @override
  String get homePaysifPremier => 'Paysif PREMIER';

  @override
  String get homeRecentTransactions => 'Recent Transactions';

  @override
  String get homeViewAll => 'View All';

  @override
  String get homeNoTransactions => 'No transactions yet';

  @override
  String get homeNoTransactionsDesc =>
      'Your financial activity will appear here once you start using your card.';

  @override
  String get historyTitle => 'Activity Stream';

  @override
  String get historyNoActivity => 'No Activity Yet';

  @override
  String get scanTitle => 'Scan QR Code';

  @override
  String get scanErrorCamera => 'Camera Error';

  @override
  String get scanGuideTitle => 'Thai QR Payment Guide';

  @override
  String get scanGuidePromptPayTitle => 'What is PromptPay?';

  @override
  String get scanGuidePromptPayDesc =>
      'Thailand\'s national mobile payment system.';

  @override
  String get scanGuideSafeTitle => 'Is it safe?';

  @override
  String get scanGuideSafeDesc => 'Yes! All transactions are verified.';

  @override
  String get scanGuideCurrencyTitle => 'Currency';

  @override
  String get scanGuideCurrencyDesc => 'We show prices in both Baht and USD.';

  @override
  String get scanPaymentSuccess => 'Payment Successful!';

  @override
  String get scanNoQrFound => 'No QR code found in image';

  @override
  String get topUpTitle => 'Add Money';

  @override
  String get topUpAmountLabel => 'Amount to Add';

  @override
  String get topUpEnterAmount => 'Enter amount';

  @override
  String get topUpPreviewTitle => 'After top-up';

  @override
  String get topUpPreviewSubtitle => 'will be added';

  @override
  String get topUpTrustSecured => 'Secured';

  @override
  String get topUpTrustNoFees => 'No fees';

  @override
  String get topUpTrustInstant => 'Instant';

  @override
  String get cardTitle => 'Add New Card';

  @override
  String get cardNumber => 'Card Number';

  @override
  String get cardInvalidNumber => 'Invalid card number';

  @override
  String get cardExpiry => 'Expiry Date';

  @override
  String get cardExpiryHint => 'MM/YY';

  @override
  String get cardInvalidDate => 'Invalid';

  @override
  String get cardUseMMYY => 'Use MM/YY';

  @override
  String get cardCVV => 'CVV';

  @override
  String get cardInvalidCVV => 'Invalid CVV';

  @override
  String get cardHolder => 'Cardholder Name';

  @override
  String get cardHolderHint => 'JOHN DOE';

  @override
  String get cardAddedSuccess => 'Card Added Successfully';

  @override
  String get cardPreviewTitle => 'Premium Card';

  @override
  String get cardPreviewHolder => 'CARD HOLDER';

  @override
  String get cardPreviewExpires => 'EXPIRES';

  @override
  String get cardAddBtn => 'Add Card';

  @override
  String get confirmTitle => 'Confirm Payment';

  @override
  String get confirmBestOption => 'Best Option';

  @override
  String get confirmEnterAmount => 'Enter Amount';

  @override
  String get confirmTotalPayment => 'Total Payment';

  @override
  String get confirmPaymentSuccess => 'Payment Successful';

  @override
  String get confirmMyWallet => 'My Wallet';

  @override
  String get walletZeroFees => 'Zero Fees';

  @override
  String get walletInstantTransfer => 'Instant Transfer';

  @override
  String get walletReliablePayment => 'Reliable Payment';

  @override
  String get walletPaymentMethod => 'Payment Method';

  @override
  String get scanUnknownRecipient => 'Unknown Recipient';

  @override
  String get profileGuestUser => 'Guest User';
}
