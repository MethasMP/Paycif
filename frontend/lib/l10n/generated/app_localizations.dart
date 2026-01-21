import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale('ko'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Paysif'**
  String get appTitle;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get navHistory;

  /// No description provided for @navPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get navPayment;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @navScan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get navScan;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get profileTitle;

  /// No description provided for @passportLabel.
  ///
  /// In en, this message translates to:
  /// **'PASSPORT'**
  String get passportLabel;

  /// No description provided for @accountSecurity.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT SECURITY'**
  String get accountSecurity;

  /// No description provided for @biometricLogin.
  ///
  /// In en, this message translates to:
  /// **'Biometric Login'**
  String get biometricLogin;

  /// No description provided for @changePin.
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get changePin;

  /// No description provided for @linkedDevices.
  ///
  /// In en, this message translates to:
  /// **'Linked Devices'**
  String get linkedDevices;

  /// No description provided for @preferences.
  ///
  /// In en, this message translates to:
  /// **'PREFERENCES'**
  String get preferences;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @lightMode.
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get lightMode;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @support.
  ///
  /// In en, this message translates to:
  /// **'SUPPORT'**
  String get support;

  /// No description provided for @helpCenter.
  ///
  /// In en, this message translates to:
  /// **'Help Center'**
  String get helpCenter;

  /// No description provided for @contactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact Support'**
  String get contactSupport;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @paymentStatus.
  ///
  /// In en, this message translates to:
  /// **'Payment Status'**
  String get paymentStatus;

  /// No description provided for @paymentReady.
  ///
  /// In en, this message translates to:
  /// **'READY'**
  String get paymentReady;

  /// No description provided for @paymentReliable.
  ///
  /// In en, this message translates to:
  /// **'reliable'**
  String get paymentReliable;

  /// No description provided for @paymentInstant.
  ///
  /// In en, this message translates to:
  /// **'Instant'**
  String get paymentInstant;

  /// No description provided for @paymentNoFees.
  ///
  /// In en, this message translates to:
  /// **'No Fees'**
  String get paymentNoFees;

  /// No description provided for @paymentAddMethod.
  ///
  /// In en, this message translates to:
  /// **'Add Payment Method'**
  String get paymentAddMethod;

  /// No description provided for @paymentEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No Payment Method Yet'**
  String get paymentEmptyTitle;

  /// No description provided for @paymentEmptyDesc.
  ///
  /// In en, this message translates to:
  /// **'Once you add a payment method, we\'ll automatically select the best option for every transaction.'**
  String get paymentEmptyDesc;

  /// No description provided for @paymentChangeMethod.
  ///
  /// In en, this message translates to:
  /// **'Change method (if needed)'**
  String get paymentChangeMethod;

  /// No description provided for @paymentHideOptions.
  ///
  /// In en, this message translates to:
  /// **'Hide other options'**
  String get paymentHideOptions;

  /// No description provided for @sheetAddPayment.
  ///
  /// In en, this message translates to:
  /// **'Add Payment Method'**
  String get sheetAddPayment;

  /// No description provided for @sheetCreditCard.
  ///
  /// In en, this message translates to:
  /// **'Credit or Debit Card'**
  String get sheetCreditCard;

  /// No description provided for @sheetCreditCardDesc.
  ///
  /// In en, this message translates to:
  /// **'Visa, Mastercard, JCB, Amex'**
  String get sheetCreditCardDesc;

  /// No description provided for @sheetTopUp.
  ///
  /// In en, this message translates to:
  /// **'Top Up Paysif Balance'**
  String get sheetTopUp;

  /// No description provided for @sheetTopUpDesc.
  ///
  /// In en, this message translates to:
  /// **'Via Bank Transfer or PromptPay'**
  String get sheetTopUpDesc;

  /// No description provided for @sheetDigitalWallet.
  ///
  /// In en, this message translates to:
  /// **'Connect Digital Wallet'**
  String get sheetDigitalWallet;

  /// No description provided for @sheetDigitalWalletDesc.
  ///
  /// In en, this message translates to:
  /// **'PayPal, Alipay, WeChat Pay'**
  String get sheetDigitalWalletDesc;

  /// No description provided for @commonEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get commonEnabled;

  /// No description provided for @commonDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get commonDisabled;

  /// No description provided for @commonSuccess.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get commonSuccess;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get commonError;

  /// No description provided for @commonToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get commonToday;

  /// No description provided for @commonYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get commonYesterday;

  /// No description provided for @commonApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get commonApply;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get commonUpload;

  /// No description provided for @commonHelp.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get commonHelp;

  /// No description provided for @commonGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it!'**
  String get commonGotIt;

  /// No description provided for @commonRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get commonRequired;

  /// No description provided for @commonInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid'**
  String get commonInvalid;

  /// No description provided for @homeTopUp.
  ///
  /// In en, this message translates to:
  /// **'Top Up'**
  String get homeTopUp;

  /// No description provided for @homeInfo.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get homeInfo;

  /// No description provided for @homeMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get homeMore;

  /// No description provided for @homeTotalBalance.
  ///
  /// In en, this message translates to:
  /// **'Total Balance'**
  String get homeTotalBalance;

  /// No description provided for @homeShow.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get homeShow;

  /// No description provided for @homeHide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get homeHide;

  /// No description provided for @homeWorldMember.
  ///
  /// In en, this message translates to:
  /// **'WORLD MEMBER'**
  String get homeWorldMember;

  /// No description provided for @homePaysifPremier.
  ///
  /// In en, this message translates to:
  /// **'Paysif PREMIER'**
  String get homePaysifPremier;

  /// No description provided for @homeRecentTransactions.
  ///
  /// In en, this message translates to:
  /// **'Recent Transactions'**
  String get homeRecentTransactions;

  /// No description provided for @homeViewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get homeViewAll;

  /// No description provided for @homeNoTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get homeNoTransactions;

  /// No description provided for @homeNoTransactionsDesc.
  ///
  /// In en, this message translates to:
  /// **'Your financial activity will appear here once you start using your card.'**
  String get homeNoTransactionsDesc;

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'Activity Stream'**
  String get historyTitle;

  /// No description provided for @historyNoActivity.
  ///
  /// In en, this message translates to:
  /// **'No Activity Yet'**
  String get historyNoActivity;

  /// No description provided for @scanTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan QR Code'**
  String get scanTitle;

  /// No description provided for @scanErrorCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera Error'**
  String get scanErrorCamera;

  /// No description provided for @scanGuideTitle.
  ///
  /// In en, this message translates to:
  /// **'Thai QR Payment Guide'**
  String get scanGuideTitle;

  /// No description provided for @scanGuidePromptPayTitle.
  ///
  /// In en, this message translates to:
  /// **'What is PromptPay?'**
  String get scanGuidePromptPayTitle;

  /// No description provided for @scanGuidePromptPayDesc.
  ///
  /// In en, this message translates to:
  /// **'Thailand\'s national mobile payment system.'**
  String get scanGuidePromptPayDesc;

  /// No description provided for @scanGuideSafeTitle.
  ///
  /// In en, this message translates to:
  /// **'Is it safe?'**
  String get scanGuideSafeTitle;

  /// No description provided for @scanGuideSafeDesc.
  ///
  /// In en, this message translates to:
  /// **'Yes! All transactions are verified.'**
  String get scanGuideSafeDesc;

  /// No description provided for @scanGuideCurrencyTitle.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get scanGuideCurrencyTitle;

  /// No description provided for @scanGuideCurrencyDesc.
  ///
  /// In en, this message translates to:
  /// **'We show prices in both Baht and USD.'**
  String get scanGuideCurrencyDesc;

  /// No description provided for @scanPaymentSuccess.
  ///
  /// In en, this message translates to:
  /// **'Payment Successful!'**
  String get scanPaymentSuccess;

  /// No description provided for @scanNoQrFound.
  ///
  /// In en, this message translates to:
  /// **'No QR code found in image'**
  String get scanNoQrFound;

  /// No description provided for @topUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Money'**
  String get topUpTitle;

  /// No description provided for @topUpAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount to Add'**
  String get topUpAmountLabel;

  /// No description provided for @topUpEnterAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter amount'**
  String get topUpEnterAmount;

  /// No description provided for @topUpPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'After top-up'**
  String get topUpPreviewTitle;

  /// No description provided for @topUpPreviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'will be added'**
  String get topUpPreviewSubtitle;

  /// No description provided for @topUpTrustSecured.
  ///
  /// In en, this message translates to:
  /// **'Secured'**
  String get topUpTrustSecured;

  /// No description provided for @topUpTrustNoFees.
  ///
  /// In en, this message translates to:
  /// **'No fees'**
  String get topUpTrustNoFees;

  /// No description provided for @topUpTrustInstant.
  ///
  /// In en, this message translates to:
  /// **'Instant'**
  String get topUpTrustInstant;

  /// No description provided for @cardTitle.
  ///
  /// In en, this message translates to:
  /// **'Add New Card'**
  String get cardTitle;

  /// No description provided for @cardNumber.
  ///
  /// In en, this message translates to:
  /// **'Card Number'**
  String get cardNumber;

  /// No description provided for @cardInvalidNumber.
  ///
  /// In en, this message translates to:
  /// **'Invalid card number'**
  String get cardInvalidNumber;

  /// No description provided for @cardExpiry.
  ///
  /// In en, this message translates to:
  /// **'Expiry Date'**
  String get cardExpiry;

  /// No description provided for @cardExpiryHint.
  ///
  /// In en, this message translates to:
  /// **'MM/YY'**
  String get cardExpiryHint;

  /// No description provided for @cardInvalidDate.
  ///
  /// In en, this message translates to:
  /// **'Invalid'**
  String get cardInvalidDate;

  /// No description provided for @cardUseMMYY.
  ///
  /// In en, this message translates to:
  /// **'Use MM/YY'**
  String get cardUseMMYY;

  /// No description provided for @cardCVV.
  ///
  /// In en, this message translates to:
  /// **'CVV'**
  String get cardCVV;

  /// No description provided for @cardInvalidCVV.
  ///
  /// In en, this message translates to:
  /// **'Invalid CVV'**
  String get cardInvalidCVV;

  /// No description provided for @cardHolder.
  ///
  /// In en, this message translates to:
  /// **'Cardholder Name'**
  String get cardHolder;

  /// No description provided for @cardHolderHint.
  ///
  /// In en, this message translates to:
  /// **'JOHN DOE'**
  String get cardHolderHint;

  /// No description provided for @cardAddedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Card Added Successfully'**
  String get cardAddedSuccess;

  /// No description provided for @cardPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Premium Card'**
  String get cardPreviewTitle;

  /// No description provided for @cardPreviewHolder.
  ///
  /// In en, this message translates to:
  /// **'CARD HOLDER'**
  String get cardPreviewHolder;

  /// No description provided for @cardPreviewExpires.
  ///
  /// In en, this message translates to:
  /// **'EXPIRES'**
  String get cardPreviewExpires;

  /// No description provided for @cardAddBtn.
  ///
  /// In en, this message translates to:
  /// **'Add Card'**
  String get cardAddBtn;

  /// No description provided for @confirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Payment'**
  String get confirmTitle;

  /// No description provided for @confirmBestOption.
  ///
  /// In en, this message translates to:
  /// **'Best Option'**
  String get confirmBestOption;

  /// No description provided for @confirmEnterAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter Amount'**
  String get confirmEnterAmount;

  /// No description provided for @confirmTotalPayment.
  ///
  /// In en, this message translates to:
  /// **'Total Payment'**
  String get confirmTotalPayment;

  /// No description provided for @confirmPaymentSuccess.
  ///
  /// In en, this message translates to:
  /// **'Payment Successful'**
  String get confirmPaymentSuccess;

  /// No description provided for @confirmMyWallet.
  ///
  /// In en, this message translates to:
  /// **'My Wallet'**
  String get confirmMyWallet;

  /// No description provided for @walletZeroFees.
  ///
  /// In en, this message translates to:
  /// **'Zero Fees'**
  String get walletZeroFees;

  /// No description provided for @walletInstantTransfer.
  ///
  /// In en, this message translates to:
  /// **'Instant Transfer'**
  String get walletInstantTransfer;

  /// No description provided for @walletReliablePayment.
  ///
  /// In en, this message translates to:
  /// **'Reliable Payment'**
  String get walletReliablePayment;

  /// No description provided for @walletPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment Method'**
  String get walletPaymentMethod;

  /// No description provided for @scanUnknownRecipient.
  ///
  /// In en, this message translates to:
  /// **'Unknown Recipient'**
  String get scanUnknownRecipient;

  /// No description provided for @profileGuestUser.
  ///
  /// In en, this message translates to:
  /// **'Guest User'**
  String get profileGuestUser;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja', 'ko', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
