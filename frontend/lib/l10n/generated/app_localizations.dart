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
  /// **'Paycif'**
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
  /// **'Top Up Paycif Balance'**
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

  /// No description provided for @commonValidationFailed.
  ///
  /// In en, this message translates to:
  /// **'Please check the highlighted fields.'**
  String get commonValidationFailed;

  /// No description provided for @commonForgotPin.
  ///
  /// In en, this message translates to:
  /// **'Forgot PIN?'**
  String get commonForgotPin;

  /// No description provided for @commonDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get commonDefault;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @commonNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get commonNext;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

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

  /// No description provided for @homePaycifPremier.
  ///
  /// In en, this message translates to:
  /// **'Paycif PREMIER'**
  String get homePaycifPremier;

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

  /// No description provided for @topUpProcessingFee.
  ///
  /// In en, this message translates to:
  /// **'Transaction Fee ({percent}%)'**
  String topUpProcessingFee(String percent);

  /// No description provided for @topUpVat.
  ///
  /// In en, this message translates to:
  /// **'VAT (7%)'**
  String get topUpVat;

  /// No description provided for @topUpTotalCharge.
  ///
  /// In en, this message translates to:
  /// **'Total Charge'**
  String get topUpTotalCharge;

  /// No description provided for @topUpAmountToWallet.
  ///
  /// In en, this message translates to:
  /// **'You receive in wallet'**
  String get topUpAmountToWallet;

  /// No description provided for @topUpFeeGateway.
  ///
  /// In en, this message translates to:
  /// **'Omise Processing Fee ({percent}%)'**
  String topUpFeeGateway(String percent);

  /// No description provided for @topUpFeePaysif.
  ///
  /// In en, this message translates to:
  /// **'Paycif Service Fee'**
  String get topUpFeePaysif;

  /// No description provided for @topUpFeeFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get topUpFeeFree;

  /// No description provided for @topUpFeeInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Fee Transparency'**
  String get topUpFeeInfoTitle;

  /// No description provided for @topUpFeeInfoOmiseTitle.
  ///
  /// In en, this message translates to:
  /// **'External Costs (Omise)'**
  String get topUpFeeInfoOmiseTitle;

  /// No description provided for @topUpFeeInfoOmiseDesc.
  ///
  /// In en, this message translates to:
  /// **'Securely processed by Omise. This fee goes directly to cover gateway and card network costs (Visa/Mastercard).'**
  String get topUpFeeInfoOmiseDesc;

  /// No description provided for @topUpFeeInfoLayer1Title.
  ///
  /// In en, this message translates to:
  /// **'Government VAT'**
  String get topUpFeeInfoLayer1Title;

  /// No description provided for @topUpFeeInfoLayer1Desc.
  ///
  /// In en, this message translates to:
  /// **'Standard 7% Value Added Tax required on processing services.'**
  String get topUpFeeInfoLayer1Desc;

  /// No description provided for @topUpFeeInfoPaysifTitle.
  ///
  /// In en, this message translates to:
  /// **'Paycif Service Fee'**
  String get topUpFeeInfoPaysifTitle;

  /// No description provided for @topUpFeeInfoPaysifDesc.
  ///
  /// In en, this message translates to:
  /// **'฿0.00. We don\'t charge you for adding money. Our platform remains free for your convenience.'**
  String get topUpFeeInfoPaysifDesc;

  /// No description provided for @topUpFeeInfoSummary.
  ///
  /// In en, this message translates to:
  /// **'We believe in full transparency. You only pay for mandatory external processing costs.'**
  String get topUpFeeInfoSummary;

  /// No description provided for @topUpChargeAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Card will be charged'**
  String get topUpChargeAmountLabel;

  /// No description provided for @applePay.
  ///
  /// In en, this message translates to:
  /// **'Apple Pay'**
  String get applePay;

  /// No description provided for @topUpFeeDisclosure.
  ///
  /// In en, this message translates to:
  /// **'Includes {feePercent} processing fee'**
  String topUpFeeDisclosure(String feePercent);

  /// No description provided for @topUpChargeBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Card will be charged ฿{chargeAmount}'**
  String topUpChargeBreakdown(String chargeAmount);

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

  /// No description provided for @cardInvalidLuhn.
  ///
  /// In en, this message translates to:
  /// **'Invalid card number (Luhn Check failed)'**
  String get cardInvalidLuhn;

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
  /// **'Invalid Date'**
  String get cardInvalidDate;

  /// No description provided for @cardInvalidMonth.
  ///
  /// In en, this message translates to:
  /// **'Month must be 01-12'**
  String get cardInvalidMonth;

  /// No description provided for @cardExpired.
  ///
  /// In en, this message translates to:
  /// **'Card is expired'**
  String get cardExpired;

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

  /// No description provided for @noInternetTitle.
  ///
  /// In en, this message translates to:
  /// **'No Connection'**
  String get noInternetTitle;

  /// No description provided for @noInternetMessage.
  ///
  /// In en, this message translates to:
  /// **'Please check your internet settings.'**
  String get noInternetMessage;

  /// No description provided for @noInternetRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get noInternetRetry;

  /// No description provided for @splashLoading.
  ///
  /// In en, this message translates to:
  /// **'Connecting to services...'**
  String get splashLoading;

  /// No description provided for @paymentSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment Successful!'**
  String get paymentSuccessTitle;

  /// No description provided for @commonSomethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get commonSomethingWentWrong;

  /// No description provided for @transactionDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Transaction Details'**
  String get transactionDetailsTitle;

  /// No description provided for @transactionHelp.
  ///
  /// In en, this message translates to:
  /// **'Need help with this transaction?'**
  String get transactionHelp;

  /// No description provided for @loginAppleComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Apple ID Integration coming soon'**
  String get loginAppleComingSoon;

  /// No description provided for @commonSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Session Expired'**
  String get commonSessionExpired;

  /// No description provided for @commonLogIn.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get commonLogIn;

  /// No description provided for @topUpEnterAmountError.
  ///
  /// In en, this message translates to:
  /// **'Please enter an amount'**
  String get topUpEnterAmountError;

  /// No description provided for @confirmPaymentFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment Failed'**
  String get confirmPaymentFailed;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @errorCardInvalid.
  ///
  /// In en, this message translates to:
  /// **'The card information is incorrect. Please check and try again.'**
  String get errorCardInvalid;

  /// No description provided for @errorInsufficientFunds.
  ///
  /// In en, this message translates to:
  /// **'Insufficient funds in your account.'**
  String get errorInsufficientFunds;

  /// No description provided for @errorProcessingFailed.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t process this payment. Please try again later.'**
  String get errorProcessingFailed;

  /// No description provided for @errorConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection error. Please check your internet and try again.'**
  String get errorConnectionFailed;

  /// No description provided for @errorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again later.'**
  String get errorUnknown;

  /// No description provided for @errorAuthenticationFailed.
  ///
  /// In en, this message translates to:
  /// **'Verification failed. Please try again.'**
  String get errorAuthenticationFailed;

  /// No description provided for @errorExpiredCard.
  ///
  /// In en, this message translates to:
  /// **'This card has expired. Please use a different card.'**
  String get errorExpiredCard;

  /// No description provided for @errorBrandNotSupported.
  ///
  /// In en, this message translates to:
  /// **'This card brand is not supported yet.'**
  String get errorBrandNotSupported;

  /// No description provided for @paymentFailedSetDefault.
  ///
  /// In en, this message translates to:
  /// **'Failed to set default method'**
  String get paymentFailedSetDefault;

  /// No description provided for @cardDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Card'**
  String get cardDeleteTitle;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @cardDeleteSuccess.
  ///
  /// In en, this message translates to:
  /// **'Card deleted successfully'**
  String get cardDeleteSuccess;

  /// No description provided for @cardDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete the card ending in {lastDigits}?'**
  String cardDeleteConfirm(String lastDigits);

  /// No description provided for @paymentSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment Settings'**
  String get paymentSettingsTitle;

  /// No description provided for @paymentPayWithApple.
  ///
  /// In en, this message translates to:
  /// **'Pay with Apple Pay'**
  String get paymentPayWithApple;

  /// No description provided for @paymentPayWith.
  ///
  /// In en, this message translates to:
  /// **'Pay with {method}'**
  String paymentPayWith(String method);

  /// No description provided for @transactionReceivedFrom.
  ///
  /// In en, this message translates to:
  /// **'Received from'**
  String get transactionReceivedFrom;

  /// No description provided for @transactionPaidTo.
  ///
  /// In en, this message translates to:
  /// **'Paid to'**
  String get transactionPaidTo;

  /// No description provided for @transactionMerchantPayment.
  ///
  /// In en, this message translates to:
  /// **'Merchant Payment'**
  String get transactionMerchantPayment;

  /// No description provided for @transactionTopUpLabel.
  ///
  /// In en, this message translates to:
  /// **'Top Up'**
  String get transactionTopUpLabel;

  /// No description provided for @transactionStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get transactionStatus;

  /// No description provided for @transactionStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get transactionStatusCompleted;

  /// No description provided for @transactionTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get transactionTime;

  /// No description provided for @transactionId.
  ///
  /// In en, this message translates to:
  /// **'Transaction ID'**
  String get transactionId;

  /// No description provided for @transactionMethod.
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get transactionMethod;

  /// No description provided for @transactionBankTransfer.
  ///
  /// In en, this message translates to:
  /// **'Bank Transfer'**
  String get transactionBankTransfer;

  /// No description provided for @transactionPaycifWallet.
  ///
  /// In en, this message translates to:
  /// **'Paycif Wallet'**
  String get transactionPaycifWallet;

  /// No description provided for @transactionSupportTicketCreated.
  ///
  /// In en, this message translates to:
  /// **'Support ticket created. We will contact you soon.'**
  String get transactionSupportTicketCreated;

  /// No description provided for @confirmReason.
  ///
  /// In en, this message translates to:
  /// **'Confirm payment of ฿{amount}'**
  String confirmReason(String amount);

  /// No description provided for @confirmAuthFailed.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed: {error}'**
  String confirmAuthFailed(String error);

  /// No description provided for @confirmPaymentTo.
  ///
  /// In en, this message translates to:
  /// **'Payment to {recipient}'**
  String confirmPaymentTo(String recipient);

  /// No description provided for @confirmAmountToPay.
  ///
  /// In en, this message translates to:
  /// **'Amount to Pay'**
  String get confirmAmountToPay;

  /// No description provided for @confirmAmountSetByMerchant.
  ///
  /// In en, this message translates to:
  /// **'Amount set by merchant'**
  String get confirmAmountSetByMerchant;

  /// No description provided for @confirmPayWith.
  ///
  /// In en, this message translates to:
  /// **'Pay with'**
  String get confirmPayWith;

  /// No description provided for @confirmPaycifBalance.
  ///
  /// In en, this message translates to:
  /// **'Paycif Balance'**
  String get confirmPaycifBalance;

  /// No description provided for @confirmPayingTo.
  ///
  /// In en, this message translates to:
  /// **'Paying to'**
  String get confirmPayingTo;

  /// No description provided for @confirmFindingBestRoute.
  ///
  /// In en, this message translates to:
  /// **'Finding best route...'**
  String get confirmFindingBestRoute;

  /// No description provided for @confirmOptimizedRoute.
  ///
  /// In en, this message translates to:
  /// **'Optimized Route'**
  String get confirmOptimizedRoute;

  /// No description provided for @confirmAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get confirmAmount;

  /// No description provided for @confirmFee.
  ///
  /// In en, this message translates to:
  /// **'Fee'**
  String get confirmFee;

  /// No description provided for @confirmSwipeToPay.
  ///
  /// In en, this message translates to:
  /// **'Swipe to Pay'**
  String get confirmSwipeToPay;

  /// No description provided for @confirmProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get confirmProcessing;

  /// No description provided for @topUpPayAmount.
  ///
  /// In en, this message translates to:
  /// **'Pay ฿{amount}'**
  String topUpPayAmount(String amount);

  /// No description provided for @topUpCardNumber.
  ///
  /// In en, this message translates to:
  /// **'Card Number'**
  String get topUpCardNumber;

  /// No description provided for @topUpExpiry.
  ///
  /// In en, this message translates to:
  /// **'Expiry'**
  String get topUpExpiry;

  /// No description provided for @topUpCVV.
  ///
  /// In en, this message translates to:
  /// **'CVV'**
  String get topUpCVV;

  /// No description provided for @topUpNameOnCard.
  ///
  /// In en, this message translates to:
  /// **'Name on Card'**
  String get topUpNameOnCard;

  /// No description provided for @topUpPayNow.
  ///
  /// In en, this message translates to:
  /// **'Pay Now'**
  String get topUpPayNow;

  /// No description provided for @topUpTestCardHint.
  ///
  /// In en, this message translates to:
  /// **'Test Card: 4242 4242... (Any future date)'**
  String get topUpTestCardHint;

  /// No description provided for @biometricLabel.
  ///
  /// In en, this message translates to:
  /// **'Biometric'**
  String get biometricLabel;

  /// No description provided for @biometricSettingsUpdated.
  ///
  /// In en, this message translates to:
  /// **'Biometric settings updated'**
  String get biometricSettingsUpdated;

  /// No description provided for @biometricNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Biometric not available on this device'**
  String get biometricNotAvailable;

  /// No description provided for @biometricNotEnrolled.
  ///
  /// In en, this message translates to:
  /// **'No biometrics enrolled. Please set up in device settings.'**
  String get biometricNotEnrolled;

  /// No description provided for @biometricConfirmManage.
  ///
  /// In en, this message translates to:
  /// **'Confirm to manage biometric settings'**
  String get biometricConfirmManage;

  /// No description provided for @kycStatusVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get kycStatusVerified;

  /// No description provided for @kycStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get kycStatusPending;

  /// No description provided for @kycStatusUnverified.
  ///
  /// In en, this message translates to:
  /// **'Not Verified'**
  String get kycStatusUnverified;

  /// No description provided for @aboutApp.
  ///
  /// In en, this message translates to:
  /// **'ABOUT'**
  String get aboutApp;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @signOutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOutConfirmTitle;

  /// No description provided for @signOutConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out?'**
  String get signOutConfirmMessage;

  /// No description provided for @helpSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search for help...'**
  String get helpSearchHint;

  /// No description provided for @helpNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get helpNoResults;

  /// No description provided for @helpStillNeedHelp.
  ///
  /// In en, this message translates to:
  /// **'Still need help?'**
  String get helpStillNeedHelp;

  /// No description provided for @helpContactTeam.
  ///
  /// In en, this message translates to:
  /// **'Our support team is here for you 24/7'**
  String get helpContactTeam;

  /// No description provided for @helpWalletTitle.
  ///
  /// In en, this message translates to:
  /// **'Wallet & Balance'**
  String get helpWalletTitle;

  /// No description provided for @helpWalletQ1.
  ///
  /// In en, this message translates to:
  /// **'How do I top up my wallet?'**
  String get helpWalletQ1;

  /// No description provided for @helpWalletA1.
  ///
  /// In en, this message translates to:
  /// **'You can top up your wallet using credit/debit cards or bank transfer. Go to Home > Top Up and choose your preferred method.'**
  String get helpWalletA1;

  /// No description provided for @helpWalletQ2.
  ///
  /// In en, this message translates to:
  /// **'What is the maximum balance limit?'**
  String get helpWalletQ2;

  /// No description provided for @helpWalletA2.
  ///
  /// In en, this message translates to:
  /// **'The maximum balance depends on your verification level. Verified users can hold up to ฿500,000. Unverified users are limited to ฿50,000.'**
  String get helpWalletA2;

  /// No description provided for @helpWalletQ3.
  ///
  /// In en, this message translates to:
  /// **'How long does top-up take?'**
  String get helpWalletQ3;

  /// No description provided for @helpWalletA3.
  ///
  /// In en, this message translates to:
  /// **'Card top-ups are instant. Bank transfers typically take 1-2 business hours during banking hours.'**
  String get helpWalletA3;

  /// No description provided for @helpPaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Payments & Transfers'**
  String get helpPaymentTitle;

  /// No description provided for @helpPaymentQ1.
  ///
  /// In en, this message translates to:
  /// **'How do I scan a QR code to pay?'**
  String get helpPaymentQ1;

  /// No description provided for @helpPaymentA1.
  ///
  /// In en, this message translates to:
  /// **'Tap the scan button in the center of the navigation bar. Point your camera at the QR code and the payment details will appear automatically.'**
  String get helpPaymentA1;

  /// No description provided for @helpPaymentQ2.
  ///
  /// In en, this message translates to:
  /// **'Are there any transaction fees?'**
  String get helpPaymentQ2;

  /// No description provided for @helpPaymentA2.
  ///
  /// In en, this message translates to:
  /// **'Paycif charges zero fees for QR payments and transfers between Paycif users. Some top-up methods may have minimal fees.'**
  String get helpPaymentA2;

  /// No description provided for @helpPaymentQ3.
  ///
  /// In en, this message translates to:
  /// **'What is the daily transaction limit?'**
  String get helpPaymentQ3;

  /// No description provided for @helpPaymentA3.
  ///
  /// In en, this message translates to:
  /// **'Verified users can transact up to ฿200,000 per day. Unverified users are limited to ฿20,000 per day.'**
  String get helpPaymentA3;

  /// No description provided for @helpSecurityTitle.
  ///
  /// In en, this message translates to:
  /// **'Security & Privacy'**
  String get helpSecurityTitle;

  /// No description provided for @helpSecurityQ1.
  ///
  /// In en, this message translates to:
  /// **'Is my money safe?'**
  String get helpSecurityQ1;

  /// No description provided for @helpSecurityA1.
  ///
  /// In en, this message translates to:
  /// **'Yes. Your funds are protected by bank-grade encryption and stored in regulated partner banks. We also offer biometric authentication for extra security.'**
  String get helpSecurityA1;

  /// No description provided for @helpSecurityQ2.
  ///
  /// In en, this message translates to:
  /// **'How do I enable biometric login?'**
  String get helpSecurityQ2;

  /// No description provided for @helpSecurityA2.
  ///
  /// In en, this message translates to:
  /// **'Go to Profile > Account Security > Biometric and toggle it on. You\'ll need to verify with your fingerprint or face to enable this feature.'**
  String get helpSecurityA2;

  /// No description provided for @helpCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Cards & Payment Methods'**
  String get helpCardTitle;

  /// No description provided for @helpCardQ1.
  ///
  /// In en, this message translates to:
  /// **'Which cards are supported?'**
  String get helpCardQ1;

  /// No description provided for @helpCardA1.
  ///
  /// In en, this message translates to:
  /// **'We support Visa, Mastercard, JCB, and American Express. Both credit and debit cards are accepted.'**
  String get helpCardA1;

  /// No description provided for @helpCardQ2.
  ///
  /// In en, this message translates to:
  /// **'How do I remove a saved card?'**
  String get helpCardQ2;

  /// No description provided for @helpCardA2.
  ///
  /// In en, this message translates to:
  /// **'Go to Payment > Your saved card > Swipe left or tap the menu icon > Delete. You\'ll be asked to confirm before removal.'**
  String get helpCardA2;

  /// No description provided for @supportHeaderTitle.
  ///
  /// In en, this message translates to:
  /// **'We\'re here to help'**
  String get supportHeaderTitle;

  /// No description provided for @supportHeaderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Usually responds within 2 hours'**
  String get supportHeaderSubtitle;

  /// No description provided for @supportSelectCategory.
  ///
  /// In en, this message translates to:
  /// **'What can we help you with?'**
  String get supportSelectCategory;

  /// No description provided for @supportCategoryGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get supportCategoryGeneral;

  /// No description provided for @supportCategoryPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get supportCategoryPayment;

  /// No description provided for @supportCategoryAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get supportCategoryAccount;

  /// No description provided for @supportCategoryTechnical.
  ///
  /// In en, this message translates to:
  /// **'Technical'**
  String get supportCategoryTechnical;

  /// No description provided for @supportSubject.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get supportSubject;

  /// No description provided for @supportSubjectHint.
  ///
  /// In en, this message translates to:
  /// **'Brief description of your issue'**
  String get supportSubjectHint;

  /// No description provided for @supportMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get supportMessage;

  /// No description provided for @supportMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Please describe your issue in detail. Include any relevant transaction IDs if applicable.'**
  String get supportMessageHint;

  /// No description provided for @supportMessageMinLength.
  ///
  /// In en, this message translates to:
  /// **'Please provide more details (minimum 20 characters)'**
  String get supportMessageMinLength;

  /// No description provided for @supportSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit Request'**
  String get supportSubmit;

  /// No description provided for @supportTicketSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Support ticket submitted. We\'ll respond within 24 hours.'**
  String get supportTicketSubmitted;

  /// No description provided for @supportAlternativeContact.
  ///
  /// In en, this message translates to:
  /// **'Or reach us directly at'**
  String get supportAlternativeContact;

  /// No description provided for @termsLastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last updated: January 2026'**
  String get termsLastUpdated;

  /// No description provided for @termsSection1Title.
  ///
  /// In en, this message translates to:
  /// **'1. Acceptance of Terms'**
  String get termsSection1Title;

  /// No description provided for @termsSection1Content.
  ///
  /// In en, this message translates to:
  /// **'By accessing or using Paycif services, you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use our services. We reserve the right to modify these terms at any time.'**
  String get termsSection1Content;

  /// No description provided for @termsSection2Title.
  ///
  /// In en, this message translates to:
  /// **'2. Account Registration'**
  String get termsSection2Title;

  /// No description provided for @termsSection2Content.
  ///
  /// In en, this message translates to:
  /// **'You must be at least 18 years old to create an account. You are responsible for maintaining the confidentiality of your account credentials. You must provide accurate and complete information during registration.'**
  String get termsSection2Content;

  /// No description provided for @termsSection3Title.
  ///
  /// In en, this message translates to:
  /// **'3. Payment Services'**
  String get termsSection3Title;

  /// No description provided for @termsSection3Content.
  ///
  /// In en, this message translates to:
  /// **'Paycif provides digital wallet and payment services. All transactions are final and non-reversible unless otherwise stated. We may impose limits on transaction amounts based on verification status and regulatory requirements.'**
  String get termsSection3Content;

  /// No description provided for @termsSection4Title.
  ///
  /// In en, this message translates to:
  /// **'4. Prohibited Activities'**
  String get termsSection4Title;

  /// No description provided for @termsSection4Content.
  ///
  /// In en, this message translates to:
  /// **'You may not use Paycif for illegal activities, money laundering, fraud, or any purpose that violates applicable laws. We reserve the right to suspend or terminate accounts engaged in prohibited activities.'**
  String get termsSection4Content;

  /// No description provided for @termsSection5Title.
  ///
  /// In en, this message translates to:
  /// **'5. Limitation of Liability'**
  String get termsSection5Title;

  /// No description provided for @termsSection5Content.
  ///
  /// In en, this message translates to:
  /// **'Paycif is not liable for any indirect, incidental, or consequential damages arising from the use of our services. Our liability is limited to the amount of funds in your account at the time of the incident.'**
  String get termsSection5Content;

  /// No description provided for @termsSection6Title.
  ///
  /// In en, this message translates to:
  /// **'6. Governing Law'**
  String get termsSection6Title;

  /// No description provided for @termsSection6Content.
  ///
  /// In en, this message translates to:
  /// **'These terms are governed by the laws of Thailand. Any disputes shall be resolved through arbitration in Bangkok, Thailand, in accordance with the rules of the Thai Arbitration Institute.'**
  String get termsSection6Content;

  /// No description provided for @termsContact.
  ///
  /// In en, this message translates to:
  /// **'For questions about these terms, please contact legal@paycif.com'**
  String get termsContact;

  /// No description provided for @privacyLastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last updated: January 2026'**
  String get privacyLastUpdated;

  /// No description provided for @privacyHighlightsTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy at a Glance'**
  String get privacyHighlightsTitle;

  /// No description provided for @privacyHighlight1.
  ///
  /// In en, this message translates to:
  /// **'We never sell your personal data to third parties'**
  String get privacyHighlight1;

  /// No description provided for @privacyHighlight2.
  ///
  /// In en, this message translates to:
  /// **'Your payment data is encrypted end-to-end'**
  String get privacyHighlight2;

  /// No description provided for @privacyHighlight3.
  ///
  /// In en, this message translates to:
  /// **'You can request deletion of your data at any time'**
  String get privacyHighlight3;

  /// No description provided for @privacyHighlight4.
  ///
  /// In en, this message translates to:
  /// **'We only collect data necessary for our services'**
  String get privacyHighlight4;

  /// No description provided for @privacySection1Title.
  ///
  /// In en, this message translates to:
  /// **'Information We Collect'**
  String get privacySection1Title;

  /// No description provided for @privacySection1Content.
  ///
  /// In en, this message translates to:
  /// **'We collect information you provide directly: name, email, phone number, government ID for verification, and payment information. We also collect usage data such as transaction history and app analytics.'**
  String get privacySection1Content;

  /// No description provided for @privacySection2Title.
  ///
  /// In en, this message translates to:
  /// **'How We Use Your Information'**
  String get privacySection2Title;

  /// No description provided for @privacySection2Content.
  ///
  /// In en, this message translates to:
  /// **'We use your information to provide and improve our services, process transactions, verify your identity, prevent fraud, and communicate with you about your account and promotions.'**
  String get privacySection2Content;

  /// No description provided for @privacySection3Title.
  ///
  /// In en, this message translates to:
  /// **'Information Sharing'**
  String get privacySection3Title;

  /// No description provided for @privacySection3Content.
  ///
  /// In en, this message translates to:
  /// **'We share information with payment processors and banks to complete transactions, regulatory authorities as required by law, and service providers who help us operate our platform under strict confidentiality agreements.'**
  String get privacySection3Content;

  /// No description provided for @privacySection4Title.
  ///
  /// In en, this message translates to:
  /// **'Data Security'**
  String get privacySection4Title;

  /// No description provided for @privacySection4Content.
  ///
  /// In en, this message translates to:
  /// **'We implement bank-grade encryption (AES-256) for all sensitive data. Our systems are regularly audited by third-party security firms. We use multi-factor authentication and biometric security options.'**
  String get privacySection4Content;

  /// No description provided for @privacySection5Title.
  ///
  /// In en, this message translates to:
  /// **'Your Rights'**
  String get privacySection5Title;

  /// No description provided for @privacySection5Content.
  ///
  /// In en, this message translates to:
  /// **'You have the right to access, correct, or delete your personal data. You can opt out of marketing communications. You may request a copy of your data in a portable format.'**
  String get privacySection5Content;

  /// No description provided for @privacyContactTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy Inquiries'**
  String get privacyContactTitle;

  /// No description provided for @privacyContactContent.
  ///
  /// In en, this message translates to:
  /// **'If you have questions about our privacy practices or wish to exercise your data rights, please contact our Data Protection Officer:'**
  String get privacyContactContent;

  /// No description provided for @notificationSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification Settings'**
  String get notificationSettingsTitle;

  /// No description provided for @notificationSecurityAlwaysOn.
  ///
  /// In en, this message translates to:
  /// **'Security (Always On)'**
  String get notificationSecurityAlwaysOn;

  /// No description provided for @notificationAccountSecurity.
  ///
  /// In en, this message translates to:
  /// **'Account Security'**
  String get notificationAccountSecurity;

  /// No description provided for @notificationAccountSecurityDesc.
  ///
  /// In en, this message translates to:
  /// **'Login alerts, device changes, and password updates.'**
  String get notificationAccountSecurityDesc;

  /// No description provided for @notificationWalletActivity.
  ///
  /// In en, this message translates to:
  /// **'Wallet Activity'**
  String get notificationWalletActivity;

  /// No description provided for @notificationTransactionAlerts.
  ///
  /// In en, this message translates to:
  /// **'Transaction Alerts'**
  String get notificationTransactionAlerts;

  /// No description provided for @notificationTransactionAlertsDesc.
  ///
  /// In en, this message translates to:
  /// **'Sent, received, and top-up notifications.'**
  String get notificationTransactionAlertsDesc;

  /// No description provided for @notificationUpdates.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get notificationUpdates;

  /// No description provided for @notificationNewsPromotions.
  ///
  /// In en, this message translates to:
  /// **'News & Promotions'**
  String get notificationNewsPromotions;

  /// No description provided for @notificationNewsPromotionsDesc.
  ///
  /// In en, this message translates to:
  /// **'Exclusive offers and feature updates.'**
  String get notificationNewsPromotionsDesc;
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
