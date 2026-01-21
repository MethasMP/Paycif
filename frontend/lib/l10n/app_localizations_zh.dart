// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'ZapPay';

  @override
  String get navHome => '首页';

  @override
  String get navHistory => '历史';

  @override
  String get navPayment => '支付';

  @override
  String get navProfile => '我的';

  @override
  String get navScan => '扫一扫';

  @override
  String get profileTitle => '个人中心';

  @override
  String get passportLabel => '通行证';

  @override
  String get accountSecurity => '账户安全';

  @override
  String get biometricLogin => '生物识别登录';

  @override
  String get changePin => '修改 PIN 码';

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
  String get support => '帮助支持';

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
  String get paymentEmptyDesc => '添加支付方式后，我们将自动为您选择最佳付款选项。';

  @override
  String get paymentChangeMethod => '更换支付方式 (如有需)';

  @override
  String get paymentHideOptions => '收起选项';

  @override
  String get sheetAddPayment => '添加支付方式';

  @override
  String get sheetCreditCard => '信用卡 / 借记卡';

  @override
  String get sheetCreditCardDesc => 'Visa, Mastercard, JCB, Amex';

  @override
  String get sheetTopUp => '充值 ZapPay 余额';

  @override
  String get sheetTopUpDesc => '银行转账 / PromptPay';

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
}
