// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'ZapPay';

  @override
  String get navHome => 'ホーム';

  @override
  String get navHistory => '履歴';

  @override
  String get navPayment => '支払い';

  @override
  String get navProfile => 'マイページ';

  @override
  String get navScan => 'スキャン';

  @override
  String get profileTitle => 'プロフィール';

  @override
  String get passportLabel => 'パスポート';

  @override
  String get accountSecurity => 'セキュリティ';

  @override
  String get biometricLogin => '生体認証ログイン';

  @override
  String get changePin => 'PIN変更';

  @override
  String get linkedDevices => 'リンク済みデバイス';

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
  String get signOut => 'ログアウト';

  @override
  String get version => 'バージョン';

  @override
  String get paymentStatus => '支払いステータス';

  @override
  String get paymentReady => '準備完了';

  @override
  String get paymentReliable => '確実';

  @override
  String get paymentInstant => '即時';

  @override
  String get paymentNoFees => '手数料なし';

  @override
  String get paymentAddMethod => '支払い方法を追加';

  @override
  String get paymentEmptyTitle => '支払い方法がありません';

  @override
  String get paymentEmptyDesc => '支払い方法を追加すると、取引ごとに最適なオプションが自動的に選択されます。';

  @override
  String get paymentChangeMethod => '支払い方法を変更 (任意)';

  @override
  String get paymentHideOptions => 'オプションを隠す';

  @override
  String get sheetAddPayment => '支払い方法を追加';

  @override
  String get sheetCreditCard => 'クレジットカード / デビットカード';

  @override
  String get sheetCreditCardDesc => 'Visa, Mastercard, JCB, Amex';

  @override
  String get sheetTopUp => 'ZapPay残高にチャージ';

  @override
  String get sheetTopUpDesc => '銀行振込 / PromptPay';

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
}
