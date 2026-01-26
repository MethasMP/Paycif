// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Paycif';

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
  String get sheetTopUp => 'Top Up Paycif Balance';

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
  String get commonValidationFailed => 'Please check the highlighted fields.';

  @override
  String get commonForgotPin => 'Forgot PIN?';

  @override
  String get commonDefault => 'Default';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonDone => 'Done';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonNext => 'Next';

  @override
  String get commonConfirm => 'Confirm';

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
  String get homePaycifPremier => 'Paycif PREMIER';

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
  String get cardInvalidLuhn => 'Invalid card number (Luhn Check failed)';

  @override
  String get cardExpiry => 'Expiry Date';

  @override
  String get cardExpiryHint => 'MM/YY';

  @override
  String get cardInvalidDate => 'Invalid Date';

  @override
  String get cardInvalidMonth => 'Month must be 01-12';

  @override
  String get cardExpired => 'Card is expired';

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

  @override
  String get noInternetTitle => 'No Connection';

  @override
  String get noInternetMessage => 'Please check your internet settings.';

  @override
  String get noInternetRetry => 'Retry';

  @override
  String get splashLoading => 'Connecting to services...';

  @override
  String get paymentSuccessTitle => 'Payment Successful!';

  @override
  String get commonSomethingWentWrong => 'Something went wrong.';

  @override
  String get transactionDetailsTitle => 'Transaction Details';

  @override
  String get transactionHelp => 'Need help with this transaction?';

  @override
  String get loginAppleComingSoon => 'Apple ID Integration coming soon';

  @override
  String get commonSessionExpired => 'Session Expired';

  @override
  String get commonLogIn => 'Log In';

  @override
  String get topUpEnterAmountError => 'Please enter an amount';

  @override
  String get confirmPaymentFailed => 'Payment Failed';

  @override
  String get commonOk => 'OK';

  @override
  String get errorCardInvalid =>
      'The card information is incorrect. Please check and try again.';

  @override
  String get errorInsufficientFunds => 'Insufficient funds in your account.';

  @override
  String get errorProcessingFailed =>
      'We couldn\'t process this payment. Please try again later.';

  @override
  String get errorConnectionFailed =>
      'Connection error. Please check your internet and try again.';

  @override
  String get errorUnknown => 'Something went wrong. Please try again later.';

  @override
  String get errorAuthenticationFailed =>
      'Verification failed. Please try again.';

  @override
  String get errorExpiredCard =>
      'This card has expired. Please use a different card.';

  @override
  String get errorBrandNotSupported => 'This card brand is not supported yet.';

  @override
  String get paymentFailedSetDefault => 'Failed to set default method';

  @override
  String get cardDeleteTitle => 'Delete Card';

  @override
  String get commonDelete => 'Delete';

  @override
  String get cardDeleteSuccess => 'Card deleted successfully';

  @override
  String cardDeleteConfirm(String lastDigits) {
    return 'Are you sure you want to delete the card ending in $lastDigits?';
  }

  @override
  String get paymentSettingsTitle => 'Payment Settings';

  @override
  String get paymentPayWithApple => 'Pay with Apple Pay';

  @override
  String paymentPayWith(String method) {
    return 'Pay with $method';
  }

  @override
  String get transactionReceivedFrom => 'Received from';

  @override
  String get transactionPaidTo => 'Paid to';

  @override
  String get transactionMerchantPayment => 'Merchant Payment';

  @override
  String get transactionTopUpLabel => 'Top Up';

  @override
  String get transactionStatus => 'Status';

  @override
  String get transactionStatusCompleted => 'Completed';

  @override
  String get transactionTime => 'Time';

  @override
  String get transactionId => 'Transaction ID';

  @override
  String get transactionMethod => 'Method';

  @override
  String get transactionBankTransfer => 'Bank Transfer';

  @override
  String get transactionPaycifWallet => 'Paycif Wallet';

  @override
  String get transactionSupportTicketCreated =>
      'Support ticket created. We will contact you soon.';

  @override
  String confirmReason(String amount) {
    return 'Confirm payment of ฿$amount';
  }

  @override
  String confirmAuthFailed(String error) {
    return 'Authentication failed: $error';
  }

  @override
  String confirmPaymentTo(String recipient) {
    return 'Payment to $recipient';
  }

  @override
  String get confirmAmountToPay => 'Amount to Pay';

  @override
  String get confirmAmountSetByMerchant => 'Amount set by merchant';

  @override
  String get confirmPayWith => 'Pay with';

  @override
  String get confirmPaycifBalance => 'Paycif Balance';

  @override
  String get confirmPayingTo => 'Paying to';

  @override
  String get confirmFindingBestRoute => 'Finding best route...';

  @override
  String get confirmOptimizedRoute => 'Optimized Route';

  @override
  String get confirmAmount => 'Amount';

  @override
  String get confirmFee => 'Fee';

  @override
  String get confirmSwipeToPay => 'Swipe to Pay';

  @override
  String get confirmProcessing => 'Processing...';

  @override
  String topUpPayAmount(String amount) {
    return 'Pay ฿$amount';
  }

  @override
  String get topUpCardNumber => 'Card Number';

  @override
  String get topUpExpiry => 'Expiry';

  @override
  String get topUpCVV => 'CVV';

  @override
  String get topUpNameOnCard => 'Name on Card';

  @override
  String get topUpPayNow => 'Pay Now';

  @override
  String get topUpTestCardHint => 'Test Card: 4242 4242... (Any future date)';

  @override
  String get biometricLabel => 'Biometric';

  @override
  String get biometricSettingsUpdated => 'Biometric settings updated';

  @override
  String get biometricNotAvailable => 'Biometric not available on this device';

  @override
  String get biometricNotEnrolled =>
      'No biometrics enrolled. Please set up in device settings.';

  @override
  String get biometricConfirmManage => 'Confirm to manage biometric settings';

  @override
  String get kycStatusVerified => 'Verified';

  @override
  String get kycStatusPending => 'Pending';

  @override
  String get kycStatusUnverified => 'Not Verified';

  @override
  String get aboutApp => 'ABOUT';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get signOutConfirmTitle => 'Sign Out';

  @override
  String get signOutConfirmMessage => 'Are you sure you want to sign out?';

  @override
  String get helpSearchHint => 'Search for help...';

  @override
  String get helpNoResults => 'No results found';

  @override
  String get helpStillNeedHelp => 'Still need help?';

  @override
  String get helpContactTeam => 'Our support team is here for you 24/7';

  @override
  String get helpWalletTitle => 'Wallet & Balance';

  @override
  String get helpWalletQ1 => 'How do I top up my wallet?';

  @override
  String get helpWalletA1 =>
      'You can top up your wallet using credit/debit cards or bank transfer. Go to Home > Top Up and choose your preferred method.';

  @override
  String get helpWalletQ2 => 'What is the maximum balance limit?';

  @override
  String get helpWalletA2 =>
      'The maximum balance depends on your verification level. Verified users can hold up to ฿500,000. Unverified users are limited to ฿50,000.';

  @override
  String get helpWalletQ3 => 'How long does top-up take?';

  @override
  String get helpWalletA3 =>
      'Card top-ups are instant. Bank transfers typically take 1-2 business hours during banking hours.';

  @override
  String get helpPaymentTitle => 'Payments & Transfers';

  @override
  String get helpPaymentQ1 => 'How do I scan a QR code to pay?';

  @override
  String get helpPaymentA1 =>
      'Tap the scan button in the center of the navigation bar. Point your camera at the QR code and the payment details will appear automatically.';

  @override
  String get helpPaymentQ2 => 'Are there any transaction fees?';

  @override
  String get helpPaymentA2 =>
      'Paycif charges zero fees for QR payments and transfers between Paycif users. Some top-up methods may have minimal fees.';

  @override
  String get helpPaymentQ3 => 'What is the daily transaction limit?';

  @override
  String get helpPaymentA3 =>
      'Verified users can transact up to ฿200,000 per day. Unverified users are limited to ฿20,000 per day.';

  @override
  String get helpSecurityTitle => 'Security & Privacy';

  @override
  String get helpSecurityQ1 => 'Is my money safe?';

  @override
  String get helpSecurityA1 =>
      'Yes. Your funds are protected by bank-grade encryption and stored in regulated partner banks. We also offer biometric authentication for extra security.';

  @override
  String get helpSecurityQ2 => 'How do I enable biometric login?';

  @override
  String get helpSecurityA2 =>
      'Go to Profile > Account Security > Biometric and toggle it on. You\'ll need to verify with your fingerprint or face to enable this feature.';

  @override
  String get helpCardTitle => 'Cards & Payment Methods';

  @override
  String get helpCardQ1 => 'Which cards are supported?';

  @override
  String get helpCardA1 =>
      'We support Visa, Mastercard, JCB, and American Express. Both credit and debit cards are accepted.';

  @override
  String get helpCardQ2 => 'How do I remove a saved card?';

  @override
  String get helpCardA2 =>
      'Go to Payment > Your saved card > Swipe left or tap the menu icon > Delete. You\'ll be asked to confirm before removal.';

  @override
  String get supportHeaderTitle => 'We\'re here to help';

  @override
  String get supportHeaderSubtitle => 'Usually responds within 2 hours';

  @override
  String get supportSelectCategory => 'What can we help you with?';

  @override
  String get supportCategoryGeneral => 'General';

  @override
  String get supportCategoryPayment => 'Payment';

  @override
  String get supportCategoryAccount => 'Account';

  @override
  String get supportCategoryTechnical => 'Technical';

  @override
  String get supportSubject => 'Subject';

  @override
  String get supportSubjectHint => 'Brief description of your issue';

  @override
  String get supportMessage => 'Message';

  @override
  String get supportMessageHint =>
      'Please describe your issue in detail. Include any relevant transaction IDs if applicable.';

  @override
  String get supportMessageMinLength =>
      'Please provide more details (minimum 20 characters)';

  @override
  String get supportSubmit => 'Submit Request';

  @override
  String get supportTicketSubmitted =>
      'Support ticket submitted. We\'ll respond within 24 hours.';

  @override
  String get supportAlternativeContact => 'Or reach us directly at';

  @override
  String get termsLastUpdated => 'Last updated: January 2026';

  @override
  String get termsSection1Title => '1. Acceptance of Terms';

  @override
  String get termsSection1Content =>
      'By accessing or using Paycif services, you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use our services. We reserve the right to modify these terms at any time.';

  @override
  String get termsSection2Title => '2. Account Registration';

  @override
  String get termsSection2Content =>
      'You must be at least 18 years old to create an account. You are responsible for maintaining the confidentiality of your account credentials. You must provide accurate and complete information during registration.';

  @override
  String get termsSection3Title => '3. Payment Services';

  @override
  String get termsSection3Content =>
      'Paycif provides digital wallet and payment services. All transactions are final and non-reversible unless otherwise stated. We may impose limits on transaction amounts based on verification status and regulatory requirements.';

  @override
  String get termsSection4Title => '4. Prohibited Activities';

  @override
  String get termsSection4Content =>
      'You may not use Paycif for illegal activities, money laundering, fraud, or any purpose that violates applicable laws. We reserve the right to suspend or terminate accounts engaged in prohibited activities.';

  @override
  String get termsSection5Title => '5. Limitation of Liability';

  @override
  String get termsSection5Content =>
      'Paycif is not liable for any indirect, incidental, or consequential damages arising from the use of our services. Our liability is limited to the amount of funds in your account at the time of the incident.';

  @override
  String get termsSection6Title => '6. Governing Law';

  @override
  String get termsSection6Content =>
      'These terms are governed by the laws of Thailand. Any disputes shall be resolved through arbitration in Bangkok, Thailand, in accordance with the rules of the Thai Arbitration Institute.';

  @override
  String get termsContact =>
      'For questions about these terms, please contact legal@paycif.com';

  @override
  String get privacyLastUpdated => 'Last updated: January 2026';

  @override
  String get privacyHighlightsTitle => 'Privacy at a Glance';

  @override
  String get privacyHighlight1 =>
      'We never sell your personal data to third parties';

  @override
  String get privacyHighlight2 => 'Your payment data is encrypted end-to-end';

  @override
  String get privacyHighlight3 =>
      'You can request deletion of your data at any time';

  @override
  String get privacyHighlight4 =>
      'We only collect data necessary for our services';

  @override
  String get privacySection1Title => 'Information We Collect';

  @override
  String get privacySection1Content =>
      'We collect information you provide directly: name, email, phone number, government ID for verification, and payment information. We also collect usage data such as transaction history and app analytics.';

  @override
  String get privacySection2Title => 'How We Use Your Information';

  @override
  String get privacySection2Content =>
      'We use your information to provide and improve our services, process transactions, verify your identity, prevent fraud, and communicate with you about your account and promotions.';

  @override
  String get privacySection3Title => 'Information Sharing';

  @override
  String get privacySection3Content =>
      'We share information with payment processors and banks to complete transactions, regulatory authorities as required by law, and service providers who help us operate our platform under strict confidentiality agreements.';

  @override
  String get privacySection4Title => 'Data Security';

  @override
  String get privacySection4Content =>
      'We implement bank-grade encryption (AES-256) for all sensitive data. Our systems are regularly audited by third-party security firms. We use multi-factor authentication and biometric security options.';

  @override
  String get privacySection5Title => 'Your Rights';

  @override
  String get privacySection5Content =>
      'You have the right to access, correct, or delete your personal data. You can opt out of marketing communications. You may request a copy of your data in a portable format.';

  @override
  String get privacyContactTitle => 'Privacy Inquiries';

  @override
  String get privacyContactContent =>
      'If you have questions about our privacy practices or wish to exercise your data rights, please contact our Data Protection Officer:';
}
