// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Paysif';

  @override
  String get navHome => '首页';

  @override
  String get navHistory => '历史';

  @override
  String get navPayment => '支付';

  @override
  String get navProfile => '我的';

  @override
  String get navScan => '扫描';

  @override
  String get profileTitle => '我的个人资料';

  @override
  String get passportLabel => '通行证';

  @override
  String get accountSecurity => '账户安全';

  @override
  String get biometricLogin => '生物识别登录';

  @override
  String get changePin => '更改 PIN 码';

  @override
  String get linkedDevices => '关联设备';

  @override
  String get preferences => '偏好设置';

  @override
  String get darkMode => '深色模式';

  @override
  String get lightMode => '浅色模式';

  @override
  String get language => '语言';

  @override
  String get notifications => '通知';

  @override
  String get support => '支持';

  @override
  String get helpCenter => '帮助中心';

  @override
  String get contactSupport => '联系客服';

  @override
  String get signOut => '退出登录';

  @override
  String get version => '版本';

  @override
  String get paymentStatus => '支付状态';

  @override
  String get paymentReady => '就绪';

  @override
  String get paymentReliable => '可靠';

  @override
  String get paymentInstant => '即时';

  @override
  String get paymentNoFees => '无手续费';

  @override
  String get paymentAddMethod => '添加支付方式';

  @override
  String get paymentEmptyTitle => '暂无支付方式';

  @override
  String get paymentEmptyDesc => '添加支付方式后，我们将自动为您选择最佳选项。';

  @override
  String get paymentChangeMethod => '更改方式（如需）';

  @override
  String get paymentHideOptions => '隐藏其他选项';

  @override
  String get sheetAddPayment => '添加支付方式';

  @override
  String get sheetCreditCard => '信用卡或借记卡';

  @override
  String get sheetCreditCardDesc => 'Visa, Mastercard, JCB, Amex';

  @override
  String get sheetTopUp => '充值 Paysif 余额';

  @override
  String get sheetTopUpDesc => '通过银行转账或 PromptPay';

  @override
  String get sheetDigitalWallet => '连接数字钱包';

  @override
  String get sheetDigitalWalletDesc => 'PayPal, Alipay, WeChat Pay';

  @override
  String get commonEnabled => '已启用';

  @override
  String get commonDisabled => '已禁用';

  @override
  String get commonSuccess => '成功';

  @override
  String get commonError => '错误';

  @override
  String get commonToday => '今天';

  @override
  String get commonYesterday => '昨天';

  @override
  String get commonApply => '应用';

  @override
  String get commonSave => '保存';

  @override
  String get commonCancel => '取消';

  @override
  String get commonUpload => '上传';

  @override
  String get commonHelp => '帮助';

  @override
  String get commonGotIt => '知道了！';

  @override
  String get commonRequired => '必填';

  @override
  String get commonInvalid => '无效';

  @override
  String get homeTopUp => '充值';

  @override
  String get homeInfo => '信息';

  @override
  String get homeMore => '更多';

  @override
  String get homeTotalBalance => '总余额';

  @override
  String get homeShow => '显示';

  @override
  String get homeHide => '隐藏';

  @override
  String get homeWorldMember => '世界会员';

  @override
  String get homePaysifPremier => 'Paysif 至尊版';

  @override
  String get homeRecentTransactions => '最近交易';

  @override
  String get homeViewAll => '查看全部';

  @override
  String get homeNoTransactions => '暂无交易';

  @override
  String get homeNoTransactionsDesc => '您的财务活动将在您开始使用卡片后显示在此处。';

  @override
  String get historyTitle => '活动流';

  @override
  String get historyNoActivity => '暂无活动';

  @override
  String get scanTitle => '扫描二维码';

  @override
  String get scanErrorCamera => '相机错误';

  @override
  String get scanGuideTitle => '由 PromptPay 指南';

  @override
  String get scanGuidePromptPayTitle => '什么是 PromptPay？';

  @override
  String get scanGuidePromptPayDesc => '泰国的国家移动支付系统。';

  @override
  String get scanGuideSafeTitle => '安全吗？';

  @override
  String get scanGuideSafeDesc => '是的！所有交易都经过验证。';

  @override
  String get scanGuideCurrencyTitle => '货币';

  @override
  String get scanGuideCurrencyDesc => '我们同时显示泰铢和美元价格。';

  @override
  String get scanPaymentSuccess => '支付成功！';

  @override
  String get scanNoQrFound => '图像中未找到二维码';

  @override
  String get topUpTitle => '充值金额';

  @override
  String get topUpAmountLabel => '充值金额';

  @override
  String get topUpEnterAmount => '输入金额';

  @override
  String get topUpPreviewTitle => '充值后';

  @override
  String get topUpPreviewSubtitle => '将添加';

  @override
  String get topUpTrustSecured => '安全';

  @override
  String get topUpTrustNoFees => '无手续费';

  @override
  String get topUpTrustInstant => '即时';

  @override
  String get cardTitle => '添加新卡';

  @override
  String get cardNumber => '卡号';

  @override
  String get cardInvalidNumber => '卡号无效';

  @override
  String get cardExpiry => '有效期';

  @override
  String get cardExpiryHint => '月/年';

  @override
  String get cardInvalidDate => '无效';

  @override
  String get cardUseMMYY => '使用 MM/YY 格式';

  @override
  String get cardCVV => 'CVV';

  @override
  String get cardInvalidCVV => 'CVV 无效';

  @override
  String get cardHolder => '持卡人姓名';

  @override
  String get cardHolderHint => 'JOHN DOE';

  @override
  String get cardAddedSuccess => '添加卡片成功';

  @override
  String get cardPreviewTitle => '高级卡';

  @override
  String get cardPreviewHolder => '持卡人';

  @override
  String get cardPreviewExpires => '有效期至';

  @override
  String get cardAddBtn => '添加卡片';

  @override
  String get confirmTitle => '确认支付';

  @override
  String get confirmBestOption => '最佳选项';

  @override
  String get confirmEnterAmount => '输入金额';

  @override
  String get confirmTotalPayment => '支付总额';

  @override
  String get confirmPaymentSuccess => '支付成功';

  @override
  String get confirmMyWallet => '我的钱包';

  @override
  String get walletZeroFees => '零手续费';

  @override
  String get walletInstantTransfer => '即时转账';

  @override
  String get walletReliablePayment => '可靠支付';

  @override
  String get walletPaymentMethod => '支付方式';

  @override
  String get scanUnknownRecipient => '未知收款人';

  @override
  String get profileGuestUser => '访客用户';
}
