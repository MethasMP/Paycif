// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'Paycif';

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
  String get passportLabel => 'PASSPORT';

  @override
  String get accountSecurity => 'アカウントセキュリティ';

  @override
  String get biometricLogin => '生体認証ログイン';

  @override
  String get changePin => 'PIN変更';

  @override
  String get linkedDevices => '連携デバイス';

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
  String get verifyIdentity => 'Verify Identity';

  @override
  String get paymentStatus => '支払いステータス';

  @override
  String get paymentReady => '準備完了';

  @override
  String get paymentReliable => '信頼';

  @override
  String get paymentInstant => '即時';

  @override
  String get paymentNoFees => '手数料無料';

  @override
  String get paymentAddMethod => '支払い方法を追加';

  @override
  String get paymentEmptyTitle => '支払い方法が未登録です';

  @override
  String get paymentEmptyDesc => '支払い方法を追加すると、すべての取引に最適なオプションが自動的に選択されます。';

  @override
  String get paymentChangeMethod => '方法を変更（必要な場合）';

  @override
  String get paymentHideOptions => '他のオプションを非表示';

  @override
  String get sheetAddPayment => '支払い方法の追加';

  @override
  String get sheetCreditCard => 'クレジットカード・デビットカード';

  @override
  String get sheetCreditCardDesc => 'Visa, Mastercard, JCB, Amex';

  @override
  String get sheetTopUp => 'Paycif残高にチャージ';

  @override
  String get sheetTopUpDesc => '銀行振込またはPromptPay';

  @override
  String get sheetDigitalWallet => 'デジタルウォレット連携';

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
  String get commonToday => '本日';

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
  String get commonGotIt => '了解しました';

  @override
  String get commonRequired => '必須';

  @override
  String get commonInvalid => '無効';

  @override
  String get commonValidationFailed => '入力内容を確認してください';

  @override
  String get commonForgotPin => 'PINを忘れましたか？';

  @override
  String get commonDefault => 'デフォルト';

  @override
  String get commonEdit => '編集';

  @override
  String get commonDone => '完了';

  @override
  String get commonContinue => '続行';

  @override
  String get commonNext => '次へ';

  @override
  String get commonConfirm => '確認';

  @override
  String get homeTopUp => '入金';

  @override
  String get homeInfo => '情報';

  @override
  String get homeMore => 'もっと見る';

  @override
  String get homeTotalBalance => '総残高';

  @override
  String get homeShow => '表示';

  @override
  String get homeHide => '非表示';

  @override
  String get homeWorldMember => 'WORLD MEMBER';

  @override
  String get homePaycifPremier => 'Paycif PREMIER';

  @override
  String get homeRecentTransactions => '最近の取引';

  @override
  String get homeViewAll => 'すべて表示';

  @override
  String get homeNoTransactions => '取引履歴がありません';

  @override
  String get homeNoTransactionsDesc => 'カードの使用を開始すると、ここに取引活動が表示されます。';

  @override
  String get historyTitle => 'アクティビティ';

  @override
  String get historyNoActivity => 'アクティビティなし';

  @override
  String get scanTitle => 'QRスキャン';

  @override
  String get scanErrorCamera => 'カメラエラー';

  @override
  String get scanGuideTitle => 'Thai QR 決済ガイド';

  @override
  String get scanGuidePromptPayTitle => 'PromptPayとは？';

  @override
  String get scanGuidePromptPayDesc => 'タイの国内共通モバイル決済システムです。';

  @override
  String get scanGuideSafeTitle => '安全性について';

  @override
  String get scanGuideSafeDesc => 'すべての取引はリアルタイムで検証されます。';

  @override
  String get scanGuideCurrencyTitle => '通貨表示';

  @override
  String get scanGuideCurrencyDesc => 'バーツと米ドルの両方で算出・表示されます。';

  @override
  String get scanPaymentSuccess => '支払い完了';

  @override
  String get scanNoQrFound => 'QRコードが見つかりません';

  @override
  String get topUpTitle => '残高チャージ';

  @override
  String get topUpAmountLabel => 'チャージ金額';

  @override
  String get topUpEnterAmount => '金額を入力してください';

  @override
  String get topUpPreviewTitle => 'チャージ後残高';

  @override
  String get topUpPreviewSubtitle => 'が追加されます';

  @override
  String get topUpTrustSecured => '暗号化保護';

  @override
  String get topUpTrustNoFees => '手数料なし';

  @override
  String get topUpTrustInstant => '即時反映';

  @override
  String topUpProcessingFee(String percent) {
    return '決済手数料 ($percent%)';
  }

  @override
  String get topUpVat => '消費税 (7%)';

  @override
  String get topUpTotalCharge => 'カード請求額';

  @override
  String get topUpAmountToWallet => 'ウォレット入金額';

  @override
  String topUpFeeGateway(String percent) {
    return 'ゲートウェイ手数料 (Omise) $percent%';
  }

  @override
  String get topUpFeePaysif => 'Paycif Service Fee';

  @override
  String get topUpFeeFree => '無料';

  @override
  String get topUpFeeInfoTitle => '取引手数料について';

  @override
  String get topUpFeeInfoOmiseTitle => 'Omiseとは？';

  @override
  String get topUpFeeInfoOmiseDesc =>
      'Omiseはタイで認可された決済ゲートウェイで、カード取引を安全に処理します。すべての取引に対して標準的な手数料がかかります。';

  @override
  String get topUpFeeInfoLayer1Title => '基本手数料（レイヤー1）';

  @override
  String get topUpFeeInfoLayer1Desc =>
      'Omiseが請求する標準処理手数料です：チャージ金額の3.65%に加え、手数料の7%の消費税。この手数料はカード決済では避けられません。';

  @override
  String get topUpFeeInfoPaysifTitle => 'Paysifプラットフォーム手数料';

  @override
  String get topUpFeeInfoPaysifDesc =>
      'Paysifは追加のプラットフォーム手数料を請求しません。決済ゲートウェイのコストのみを転嫁します。';

  @override
  String get topUpFeeInfoSummary =>
      '私たちは完全な透明性を信じています。安全な決済処理に必要な分のみをお支払いいただきます。';

  @override
  String get topUpChargeAmountLabel => 'カード請求額';

  @override
  String get applePay => 'Apple Pay';

  @override
  String topUpFeeDisclosure(String feePercent) {
    return '$feePercent の決済手数料を含む';
  }

  @override
  String topUpChargeBreakdown(String chargeAmount) {
    return 'カードから ฿$chargeAmount が請求されます';
  }

  @override
  String get cardTitle => 'カード追加';

  @override
  String get cardNumber => 'カード番号';

  @override
  String get cardInvalidNumber => '無効なカード番号です';

  @override
  String get cardInvalidLuhn => '無効なカード番号です (Luhnチェック失敗)';

  @override
  String get cardExpiry => '有効期限';

  @override
  String get cardExpiryHint => '月/年';

  @override
  String get cardInvalidDate => '無効な日付です';

  @override
  String get cardInvalidMonth => '月は01-12の間で入力してください';

  @override
  String get cardExpired => '有効期限が切れています';

  @override
  String get cardUseMMYY => 'MM/YYをご利用ください';

  @override
  String get cardCVV => 'CVV';

  @override
  String get cardInvalidCVV => '無効なCVV';

  @override
  String get cardHolder => 'カード名義';

  @override
  String get cardHolderHint => 'TARO YAMADA';

  @override
  String get cardAddedSuccess => 'カードが追加されました';

  @override
  String get cardPreviewTitle => 'Premium Card';

  @override
  String get cardPreviewHolder => 'CARD HOLDER';

  @override
  String get cardPreviewExpires => 'EXPIRES';

  @override
  String get cardAddBtn => 'カードを追加';

  @override
  String get confirmTitle => '支払い確認';

  @override
  String get confirmBestOption => '最適な選択肢';

  @override
  String get confirmEnterAmount => '金額を入力';

  @override
  String get confirmTotalPayment => '合計支払い額';

  @override
  String get confirmPaymentSuccess => 'お支払い完了';

  @override
  String get confirmMyWallet => 'マイウォレット';

  @override
  String get walletZeroFees => '手数料ゼロ';

  @override
  String get walletInstantTransfer => '即時送金';

  @override
  String get walletReliablePayment => '安全な支払い';

  @override
  String get walletPaymentMethod => '支払い方法';

  @override
  String get scanUnknownRecipient => '不明な受取人';

  @override
  String get profileGuestUser => 'ゲストユーザー';

  @override
  String get noInternetTitle => 'オフライン';

  @override
  String get noInternetMessage => 'インターネット接続を確認してください';

  @override
  String get noInternetRetry => '再試行';

  @override
  String get splashLoading => 'サーバーに接続中...';

  @override
  String get paymentSuccessTitle => '支払いが成功しました！';

  @override
  String get commonSomethingWentWrong => '問題が発生しました。';

  @override
  String get transactionDetailsTitle => '取引明細';

  @override
  String get transactionHelp => 'この取引についてヘルプが必要ですか？';

  @override
  String get loginAppleComingSoon => 'Apple ID連携は近日公開予定です';

  @override
  String get commonSessionExpired => 'セッションが終了しました';

  @override
  String get commonLogIn => 'ログイン';

  @override
  String get topUpEnterAmountError => '金額を入力してください';

  @override
  String get confirmPaymentFailed => '支払いに失敗しました';

  @override
  String get commonOk => 'OK';

  @override
  String get errorCardInvalid => 'カード情報が正しくありません。確認してもう一度お試しください。';

  @override
  String get errorInsufficientFunds => '残高が不足しています。';

  @override
  String get errorProcessingFailed => '支払いを処理できませんでした。後でもう一度お試しください。';

  @override
  String get errorConnectionFailed => '接続エラーが発生しました。インターネット接続を確認してもう一度お試しください。';

  @override
  String get errorUnknown => 'エラーが発生しました。後でもう一度お試しください。';

  @override
  String get errorAuthenticationFailed => '認証に失敗しました。もう一度お試しください。';

  @override
  String get errorExpiredCard => 'このカードは有効期限が切れています。別のカードを使用してください。';

  @override
  String get errorBrandNotSupported => 'このカードブランドはまだサポートされていません。';

  @override
  String get paymentFailedSetDefault => 'デフォルト設定に失敗しました';

  @override
  String get cardDeleteTitle => 'カード削除';

  @override
  String get commonDelete => '削除する';

  @override
  String get cardDeleteSuccess => 'カードが正常に削除されました';

  @override
  String cardDeleteConfirm(String lastDigits) {
    return 'カード（末尾$lastDigits）を削除してもよろしいですか？';
  }

  @override
  String get paymentSettingsTitle => '支払い設定';

  @override
  String get paymentPayWithApple => 'Apple Payで支払う';

  @override
  String paymentPayWith(String method) {
    return '$methodで支払う';
  }

  @override
  String get transactionReceivedFrom => '受取先:';

  @override
  String get transactionPaidTo => '支払先:';

  @override
  String get transactionMerchantPayment => '加盟店への支払い';

  @override
  String get transactionTopUpLabel => 'チャージ';

  @override
  String get transactionStatus => 'ステータス';

  @override
  String get transactionStatusCompleted => '完了';

  @override
  String get transactionTime => '日時';

  @override
  String get transactionId => '取引ID';

  @override
  String get transactionMethod => '支払い方法';

  @override
  String get transactionBankTransfer => '銀行振込';

  @override
  String get transactionPaycifWallet => 'Paycifウォレット';

  @override
  String get transactionSupportTicketCreated =>
      'サポートチケットが作成されました。まもなくご連絡いたします。';

  @override
  String confirmReason(String amount) {
    return '฿$amountの支払いを確定する';
  }

  @override
  String confirmAuthFailed(String error) {
    return '認証に失敗しました: $error';
  }

  @override
  String confirmPaymentTo(String recipient) {
    return '$recipientへの支払い';
  }

  @override
  String get confirmAmountToPay => '支払い金額';

  @override
  String get confirmAmountSetByMerchant => '加盟店設定金額';

  @override
  String get confirmPayWith => '支払い方法';

  @override
  String get confirmPaycifBalance => 'Paycif残高';

  @override
  String get confirmPayingTo => '支払い先';

  @override
  String get confirmFindingBestRoute => '最適なルートを検索中...';

  @override
  String get confirmOptimizedRoute => '最適化されたルート';

  @override
  String get confirmAmount => '金額';

  @override
  String get confirmFee => '手数料';

  @override
  String get confirmSwipeToPay => 'スワイプして支払う';

  @override
  String get confirmProcessing => '処理中...';

  @override
  String topUpPayAmount(String amount) {
    return '฿$amount支払う';
  }

  @override
  String get topUpCardNumber => 'カード番号';

  @override
  String get topUpExpiry => '有効期限';

  @override
  String get topUpCVV => 'CVV';

  @override
  String get topUpNameOnCard => 'カード名義';

  @override
  String get topUpPayNow => '今すぐ支払う';

  @override
  String get topUpTestCardHint => 'テストカード: 4242 4242... (未来の日付)';

  @override
  String get biometricLabel => '生体認証';

  @override
  String get biometricSettingsUpdated => '生体認証設定を更新しました';

  @override
  String get biometricNotAvailable => 'このデバイスでは生体認証を利用できません';

  @override
  String get biometricNotEnrolled => '生体認証が登録されていません。デバイス設定で登録してください。';

  @override
  String get biometricConfirmManage => '生体認証設定を管理するには確認してください';

  @override
  String get kycStatusVerified => '認証済み';

  @override
  String get kycStatusPending => '確認中';

  @override
  String get kycStatusUnverified => '未認証';

  @override
  String get aboutApp => 'アプリについて';

  @override
  String get termsOfService => '利用規約';

  @override
  String get privacyPolicy => 'プライバシーポリシー';

  @override
  String get signOutConfirmTitle => 'サインアウト';

  @override
  String get signOutConfirmMessage => 'サインアウトしますか？';

  @override
  String get helpSearchHint => 'ヘルプを検索...';

  @override
  String get helpNoResults => '結果が見つかりません';

  @override
  String get helpStillNeedHelp => 'まだお困りですか？';

  @override
  String get helpContactTeam => 'サポートチームが24時間対応しています';

  @override
  String get helpWalletTitle => 'ウォレット＆残高';

  @override
  String get helpWalletQ1 => 'ウォレットにチャージするには？';

  @override
  String get helpWalletA1 =>
      'クレジット/デビットカードまたは銀行振込でチャージできます。ホーム > チャージから選択してください。';

  @override
  String get helpWalletQ2 => '残高の上限は？';

  @override
  String get helpWalletA2 =>
      '上限は認証レベルによって異なります。認証済みユーザーは฿500,000まで、未認証ユーザーは฿50,000までです。';

  @override
  String get helpWalletQ3 => 'チャージにかかる時間は？';

  @override
  String get helpWalletA3 => 'カードチャージは即時反映されます。銀行振込は通常1-2営業時間かかります。';

  @override
  String get helpPaymentTitle => '決済＆送金';

  @override
  String get helpPaymentQ1 => 'QRコードで支払うには？';

  @override
  String get helpPaymentA1 => 'ナビゲーションバー中央のスキャンボタンをタップし、QRコードにカメラを向けてください。';

  @override
  String get helpPaymentQ2 => '手数料はかかりますか？';

  @override
  String get helpPaymentA2 =>
      'QR決済やPaycifユーザー間送金は無料です。一部のチャージ方法には手数料がかかる場合があります。';

  @override
  String get helpPaymentQ3 => '1日の取引上限は？';

  @override
  String get helpPaymentA3 => '認証済みユーザーは1日฿200,000まで、未認証ユーザーは฿20,000までです。';

  @override
  String get helpSecurityTitle => 'セキュリティ＆プライバシー';

  @override
  String get helpSecurityQ1 => 'お金は安全ですか？';

  @override
  String get helpSecurityA1 => 'はい。銀行レベルの暗号化で保護され、規制されたパートナー銀行に保管されています。';

  @override
  String get helpSecurityQ2 => '生体認証を有効にするには？';

  @override
  String get helpSecurityA2 => 'プロフィール > アカウントセキュリティ > 生体認証をオンにしてください。';

  @override
  String get helpCardTitle => 'カード＆支払い方法';

  @override
  String get helpCardQ1 => '対応カードは？';

  @override
  String get helpCardA1 => 'Visa、Mastercard、JCB、American Expressに対応しています。';

  @override
  String get helpCardQ2 => '保存したカードを削除するには？';

  @override
  String get helpCardA2 => '支払い > カードを左スワイプまたはメニューアイコン > 削除を選択してください。';

  @override
  String get supportHeaderTitle => 'いつでもお手伝いします';

  @override
  String get supportHeaderSubtitle => '通常2時間以内に返信します';

  @override
  String get supportSelectCategory => 'どのようなお問い合わせですか？';

  @override
  String get supportCategoryGeneral => '一般';

  @override
  String get supportCategoryPayment => '決済';

  @override
  String get supportCategoryAccount => 'アカウント';

  @override
  String get supportCategoryTechnical => '技術サポート';

  @override
  String get supportSubject => '件名';

  @override
  String get supportSubjectHint => '問題の簡単な説明';

  @override
  String get supportMessage => 'メッセージ';

  @override
  String get supportMessageHint => '問題の詳細をご記入ください。関連する取引IDがあれば記載してください。';

  @override
  String get supportMessageMinLength => '詳細をご記入ください（最低20文字）';

  @override
  String get supportSubmit => '送信する';

  @override
  String get supportTicketSubmitted => 'サポートチケットを送信しました。24時間以内に返信します。';

  @override
  String get supportAlternativeContact => 'または直接ご連絡ください';

  @override
  String get termsLastUpdated => '最終更新：2026年1月';

  @override
  String get termsSection1Title => '1. 利用規約への同意';

  @override
  String get termsSection1Content =>
      'Paycifサービスをご利用いただくことで、本利用規約に同意したものとみなされます。';

  @override
  String get termsSection2Title => '2. アカウント登録';

  @override
  String get termsSection2Content =>
      'アカウント作成には18歳以上である必要があります。認証情報の機密性を維持する責任があります。';

  @override
  String get termsSection3Title => '3. 決済サービス';

  @override
  String get termsSection3Content =>
      'Paycifはデジタルウォレットと決済サービスを提供します。取引は原則として取消不可です。';

  @override
  String get termsSection4Title => '4. 禁止事項';

  @override
  String get termsSection4Content =>
      '違法行為、マネーロンダリング、詐欺などの目的でPaycifを使用してはなりません。';

  @override
  String get termsSection5Title => '5. 責任の制限';

  @override
  String get termsSection5Content => 'Paycifは本サービスの使用から生じる間接的損害について責任を負いません。';

  @override
  String get termsSection6Title => '6. 準拠法';

  @override
  String get termsSection6Content => '本規約はタイ王国の法律に準拠します。紛争はバンコクでの仲裁により解決されます。';

  @override
  String get termsContact => '規約に関するお問い合わせ：legal@paycif.com';

  @override
  String get privacyLastUpdated => '最終更新：2026年1月';

  @override
  String get privacyHighlightsTitle => 'プライバシーの要点';

  @override
  String get privacyHighlight1 => '個人データを第三者に販売することはありません';

  @override
  String get privacyHighlight2 => '決済データはエンドツーエンドで暗号化されています';

  @override
  String get privacyHighlight3 => 'いつでもデータの削除を要求できます';

  @override
  String get privacyHighlight4 => 'サービスに必要なデータのみを収集します';

  @override
  String get privacySection1Title => '収集する情報';

  @override
  String get privacySection1Content =>
      '氏名、メール、電話番号、本人確認用身分証明書、決済情報を収集します。また取引履歴やアプリ分析データも収集します。';

  @override
  String get privacySection2Title => '情報の利用目的';

  @override
  String get privacySection2Content =>
      'サービスの提供・改善、取引処理、本人確認、不正防止、アカウント関連のご連絡に使用します。';

  @override
  String get privacySection3Title => '情報の共有';

  @override
  String get privacySection3Content =>
      '決済処理機関・銀行、法的要求に応じた規制当局、厳格な機密保持契約の下でサービスプロバイダーと共有します。';

  @override
  String get privacySection4Title => 'データセキュリティ';

  @override
  String get privacySection4Content =>
      'すべての機密データにAES-256暗号化を実装。第三者セキュリティ機関による定期監査を実施しています。';

  @override
  String get privacySection5Title => 'お客様の権利';

  @override
  String get privacySection5Content =>
      '個人データのアクセス、訂正、削除を要求する権利があります。マーケティング通知のオプトアウトも可能です。';

  @override
  String get privacyContactTitle => 'プライバシーに関するお問い合わせ';

  @override
  String get privacyContactContent =>
      'プライバシーに関するご質問やデータ権利の行使については、データ保護責任者までご連絡ください：';

  @override
  String get notificationSettingsTitle => 'Notification Settings';

  @override
  String get notificationSecurityAlwaysOn => 'Security (Always On)';

  @override
  String get notificationAccountSecurity => 'Account Security';

  @override
  String get notificationAccountSecurityDesc =>
      'Login alerts, device changes, and password updates.';

  @override
  String get notificationWalletActivity => 'Wallet Activity';

  @override
  String get notificationTransactionAlerts => 'Transaction Alerts';

  @override
  String get notificationTransactionAlertsDesc =>
      'Sent, received, and top-up notifications.';

  @override
  String get notificationUpdates => 'Updates';

  @override
  String get notificationNewsPromotions => 'News & Promotions';

  @override
  String get notificationNewsPromotionsDesc =>
      'Exclusive offers and feature updates.';
}
