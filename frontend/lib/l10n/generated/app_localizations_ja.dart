// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'Paysif';

  @override
  String get navHome => 'ホーム';

  @override
  String get navHistory => '履歴';

  @override
  String get navPayment => '支払い';

  @override
  String get navProfile => 'プロフィール';

  @override
  String get navScan => 'スキャン';

  @override
  String get profileTitle => 'マイプロフィール';

  @override
  String get passportLabel => 'パスポート';

  @override
  String get accountSecurity => 'アカウントセキュリティ';

  @override
  String get biometricLogin => '生体認証ログイン';

  @override
  String get changePin => 'PINの変更';

  @override
  String get linkedDevices => 'リンクされたデバイス';

  @override
  String get preferences => '設定';

  @override
  String get darkMode => 'ダークモード';

  @override
  String get lightMode => 'ライトモード';

  @override
  String get language => '言語';

  @override
  String get notifications => '通知';

  @override
  String get support => 'サポート';

  @override
  String get helpCenter => 'ヘルプセンター';

  @override
  String get contactSupport => 'サポートに連絡';

  @override
  String get signOut => 'サインアウト';

  @override
  String get version => 'バージョン';

  @override
  String get paymentStatus => '支払いステータス';

  @override
  String get paymentReady => '準備完了';

  @override
  String get paymentReliable => '信頼できる';

  @override
  String get paymentInstant => '即時';

  @override
  String get paymentNoFees => '手数料なし';

  @override
  String get paymentAddMethod => '支払い方法を追加';

  @override
  String get paymentEmptyTitle => '支払い方法がまだありません';

  @override
  String get paymentEmptyDesc => '支払い方法を追加すると、すべての取引に最適なオプションが自動的に選択されます。';

  @override
  String get paymentChangeMethod => '方法を変更（必要な場合）';

  @override
  String get paymentHideOptions => '他のオプションを隠す';

  @override
  String get sheetAddPayment => '支払い方法を追加';

  @override
  String get sheetCreditCard => 'クレジットカードまたはデビットカード';

  @override
  String get sheetCreditCardDesc => 'Visa, Mastercard, JCB, Amex';

  @override
  String get sheetTopUp => 'Paysif残高をチャージ';

  @override
  String get sheetTopUpDesc => '銀行振込またはPromptPay経由';

  @override
  String get sheetDigitalWallet => 'デジタルウォレットを接続';

  @override
  String get sheetDigitalWalletDesc => 'PayPal, Alipay, WeChat Pay';

  @override
  String get commonEnabled => '有効';

  @override
  String get commonDisabled => '無効';

  @override
  String get commonSuccess => '成功';

  @override
  String get commonError => 'エラー';

  @override
  String get commonToday => '今日';

  @override
  String get commonYesterday => '昨日';

  @override
  String get commonApply => '適用';

  @override
  String get commonSave => '保存';

  @override
  String get commonCancel => 'キャンセル';

  @override
  String get commonUpload => 'アップロード';

  @override
  String get commonHelp => 'ヘルプ';

  @override
  String get commonGotIt => '分かりました！';

  @override
  String get commonRequired => '必須';

  @override
  String get commonInvalid => '無効';

  @override
  String get homeTopUp => 'チャージ';

  @override
  String get homeInfo => '情報';

  @override
  String get homeMore => 'その他';

  @override
  String get homeTotalBalance => '総残高';

  @override
  String get homeShow => '表示';

  @override
  String get homeHide => '非表示';

  @override
  String get homeWorldMember => 'ワールドメンバー';

  @override
  String get homePaysifPremier => 'Paysifプレミア';

  @override
  String get homeRecentTransactions => '最近の取引';

  @override
  String get homeViewAll => 'すべて表示';

  @override
  String get homeNoTransactions => '取引はまだありません';

  @override
  String get homeNoTransactionsDesc => 'カードの使用を開始すると、ここに財務活動が表示されます。';

  @override
  String get historyTitle => 'アクティビティ';

  @override
  String get historyNoActivity => 'アクティビティはまだありません';

  @override
  String get scanTitle => 'QRコードをスキャン';

  @override
  String get scanErrorCamera => 'カメラエラー';

  @override
  String get scanGuideTitle => 'PromptPayガイド';

  @override
  String get scanGuidePromptPayTitle => 'PromptPayとは？';

  @override
  String get scanGuidePromptPayDesc => 'タイの全国モバイル決済システムです。';

  @override
  String get scanGuideSafeTitle => '安全ですか？';

  @override
  String get scanGuideSafeDesc => 'はい！すべての取引は検証されています。';

  @override
  String get scanGuideCurrencyTitle => '通貨';

  @override
  String get scanGuideCurrencyDesc => 'バーツと米ドルの両方で価格を表示します。';

  @override
  String get scanPaymentSuccess => '支払い成功！';

  @override
  String get scanNoQrFound => '画像にQRコードが見つかりません';

  @override
  String get topUpTitle => '金額を追加';

  @override
  String get topUpAmountLabel => '追加する金額';

  @override
  String get topUpEnterAmount => '金額を入力';

  @override
  String get topUpPreviewTitle => 'チャージ後';

  @override
  String get topUpPreviewSubtitle => 'が追加されます';

  @override
  String get topUpTrustSecured => '安全';

  @override
  String get topUpTrustNoFees => '手数料なし';

  @override
  String get topUpTrustInstant => '即時';

  @override
  String get cardTitle => '新しいカードを追加';

  @override
  String get cardNumber => 'カード番号';

  @override
  String get cardInvalidNumber => '無効なカード番号';

  @override
  String get cardExpiry => '有効期限';

  @override
  String get cardExpiryHint => '月/年';

  @override
  String get cardInvalidDate => '無効';

  @override
  String get cardUseMMYY => 'MM/YY形式を使用';

  @override
  String get cardCVV => 'CVV';

  @override
  String get cardInvalidCVV => '無効なCVV';

  @override
  String get cardHolder => 'カード名義人';

  @override
  String get cardHolderHint => 'JOHN DOE';

  @override
  String get cardAddedSuccess => 'カードが正常に追加されました';

  @override
  String get cardPreviewTitle => 'プレミアムカード';

  @override
  String get cardPreviewHolder => 'カード名義人';

  @override
  String get cardPreviewExpires => '有効期限';

  @override
  String get cardAddBtn => 'カード追加';

  @override
  String get confirmTitle => '支払い確認';

  @override
  String get confirmBestOption => '最適な選択';

  @override
  String get confirmEnterAmount => '金額を入力';

  @override
  String get confirmTotalPayment => '支払い合計';

  @override
  String get confirmPaymentSuccess => '支払い完了';

  @override
  String get confirmMyWallet => 'マイウォレット';

  @override
  String get walletZeroFees => '手数料無料';

  @override
  String get walletInstantTransfer => '即時送金';

  @override
  String get walletReliablePayment => '安心の支払い';

  @override
  String get walletPaymentMethod => '支払い方法';

  @override
  String get scanUnknownRecipient => '不明な受取人';

  @override
  String get profileGuestUser => 'ゲストユーザー';
}
