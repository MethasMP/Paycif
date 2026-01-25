// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Paycif';

  @override
  String get navHome => '首页';

  @override
  String get navHistory => '历史';

  @override
  String get navPayment => '支付';

  @override
  String get navProfile => '我的';

  @override
  String get navScan => '扫码';

  @override
  String get profileTitle => '个人资料';

  @override
  String get passportLabel => 'PASSPORT';

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
  String get paymentNoFees => '免手续费';

  @override
  String get paymentAddMethod => '添加支付方式';

  @override
  String get paymentEmptyTitle => '暂无支付方式';

  @override
  String get paymentEmptyDesc => '添加支付方式后，系统将为您自动选择最佳支付选项。';

  @override
  String get paymentChangeMethod => '更改方式（如有需要）';

  @override
  String get paymentHideOptions => '隐藏其他选项';

  @override
  String get sheetAddPayment => '添加支付方式';

  @override
  String get sheetCreditCard => '信用卡或借记卡';

  @override
  String get sheetCreditCardDesc => 'Visa, Mastercard, JCB, Amex';

  @override
  String get sheetTopUp => '充值 Paycif 余额';

  @override
  String get sheetTopUpDesc => '通过银行转账或 PromptPay';

  @override
  String get sheetDigitalWallet => '连接电子钱包';

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
  String get commonGotIt => '知道了';

  @override
  String get commonRequired => '必填';

  @override
  String get commonInvalid => '无效';

  @override
  String get commonValidationFailed => '请检查高亮显示的字段。';

  @override
  String get commonDefault => '默认';

  @override
  String get commonEdit => '编辑';

  @override
  String get commonDone => '完成';

  @override
  String get commonContinue => '继续';

  @override
  String get commonNext => '下一步';

  @override
  String get commonConfirm => '确认';

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
  String get homeWorldMember => 'WORLD MEMBER';

  @override
  String get homePaycifPremier => 'Paycif PREMIER';

  @override
  String get homeRecentTransactions => '最近交易';

  @override
  String get homeViewAll => '查看全部';

  @override
  String get homeNoTransactions => '暂无交易记录';

  @override
  String get homeNoTransactionsDesc => '开始使用卡片后，您的交易活动将显示在此处。';

  @override
  String get historyTitle => '交易记录';

  @override
  String get historyNoActivity => '暂无活动';

  @override
  String get scanTitle => '扫码支付';

  @override
  String get scanErrorCamera => '相机错误';

  @override
  String get scanGuideTitle => 'Thai QR 支付指南';

  @override
  String get scanGuidePromptPayTitle => '什么是 PromptPay？';

  @override
  String get scanGuidePromptPayDesc => '泰国国家级移动支付系统。';

  @override
  String get scanGuideSafeTitle => '安全性';

  @override
  String get scanGuideSafeDesc => '是的！所有交易均经过即时验证。';

  @override
  String get scanGuideCurrencyTitle => '货币';

  @override
  String get scanGuideCurrencyDesc => '我们同时显示泰铢和美元的价格。';

  @override
  String get scanPaymentSuccess => '支付成功！';

  @override
  String get scanNoQrFound => '未发现二维码';

  @override
  String get topUpTitle => '账户充值';

  @override
  String get topUpAmountLabel => '充值金额';

  @override
  String get topUpEnterAmount => '请输入金额';

  @override
  String get topUpPreviewTitle => '充值后余额';

  @override
  String get topUpPreviewSubtitle => '将被添加';

  @override
  String get topUpTrustSecured => '加密保护';

  @override
  String get topUpTrustNoFees => '免手续费';

  @override
  String get topUpTrustInstant => '即时到账';

  @override
  String get cardTitle => '添加新卡';

  @override
  String get cardNumber => '卡号';

  @override
  String get cardInvalidNumber => '卡号无效';

  @override
  String get cardInvalidLuhn => '卡号无效 (Luhn 校验失败)';

  @override
  String get cardExpiry => '有效期';

  @override
  String get cardExpiryHint => '月/年';

  @override
  String get cardInvalidDate => '日期无效';

  @override
  String get cardInvalidMonth => '月份必须在 01-12 之间';

  @override
  String get cardExpired => '卡片已过期';

  @override
  String get cardUseMMYY => '请使用 MM/YY 格式';

  @override
  String get cardCVV => 'CVV';

  @override
  String get cardInvalidCVV => '无效的 CVV';

  @override
  String get cardHolder => '持卡人姓名';

  @override
  String get cardHolderHint => 'ZHANG SAN';

  @override
  String get cardAddedSuccess => '卡片添加成功';

  @override
  String get cardPreviewTitle => 'Premium Card';

  @override
  String get cardPreviewHolder => 'CARD HOLDER';

  @override
  String get cardPreviewExpires => 'EXPIRES';

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
  String get walletReliablePayment => '安全支付';

  @override
  String get walletPaymentMethod => '支付方式';

  @override
  String get scanUnknownRecipient => '未知收款人';

  @override
  String get profileGuestUser => '游客用户';

  @override
  String get noInternetTitle => '无网络连接';

  @override
  String get noInternetMessage => '请检查您的网络设置';

  @override
  String get noInternetRetry => '重试';

  @override
  String get splashLoading => '正在连接服务...';

  @override
  String get paymentSuccessTitle => '支付成功！';

  @override
  String get commonSomethingWentWrong => '出错了。';

  @override
  String get transactionDetailsTitle => '交易详情';

  @override
  String get transactionHelp => '需要此交易的帮助吗？';

  @override
  String get loginAppleComingSoon => 'Apple ID 登录即将推出';

  @override
  String get commonSessionExpired => '会话已过期';

  @override
  String get commonLogIn => '登录';

  @override
  String get topUpEnterAmountError => '请输入金额';

  @override
  String get confirmPaymentFailed => '支付失败';

  @override
  String get commonOk => '确定';

  @override
  String get errorCardInvalid => '卡片信息有误，请核对后重试。';

  @override
  String get errorInsufficientFunds => '余额不足。';

  @override
  String get errorProcessingFailed => '无法处理此笔付款，请稍后重试。';

  @override
  String get errorConnectionFailed => '连接错误，请检查您的网络后重试。';

  @override
  String get errorUnknown => '出现问题，请稍后重试。';

  @override
  String get errorAuthenticationFailed => '身份验证失败，请重试。';

  @override
  String get errorExpiredCard => '此卡已过期，请使用其他卡片。';

  @override
  String get errorBrandNotSupported => '目前尚不支持此类型的卡片。';

  @override
  String get paymentFailedSetDefault => '设置默认方式失败';

  @override
  String get cardDeleteTitle => '删除卡片';

  @override
  String get commonDelete => '删除';

  @override
  String get cardDeleteSuccess => '卡片已成功删除';

  @override
  String cardDeleteConfirm(String lastDigits) {
    return '您确定要删除尾号为 $lastDigits 的卡片吗？';
  }

  @override
  String get paymentSettingsTitle => '支付设置';

  @override
  String get paymentPayWithApple => '使用 Apple Pay 支付';

  @override
  String paymentPayWith(String method) {
    return '使用 $method 支付';
  }

  @override
  String get transactionReceivedFrom => '收到来自';

  @override
  String get transactionPaidTo => '付给';

  @override
  String get transactionMerchantPayment => '商家支付';

  @override
  String get transactionTopUpLabel => '充值';

  @override
  String get transactionStatus => '状态';

  @override
  String get transactionStatusCompleted => '已完成';

  @override
  String get transactionTime => '时间';

  @override
  String get transactionId => '交易 ID';

  @override
  String get transactionMethod => '方式';

  @override
  String get transactionBankTransfer => '银行转账';

  @override
  String get transactionPaycifWallet => 'Paycif 钱包';

  @override
  String get transactionSupportTicketCreated => '支持工单已创建。我们将尽快与您联系。';

  @override
  String confirmReason(String amount) {
    return '确认支付 ฿$amount';
  }

  @override
  String confirmAuthFailed(String error) {
    return '身份验证失败: $error';
  }

  @override
  String confirmPaymentTo(String recipient) {
    return '支付给 $recipient';
  }

  @override
  String get confirmAmountToPay => '支付金额';

  @override
  String get confirmAmountSetByMerchant => '商家设定的金额';

  @override
  String get confirmPayWith => '支付方式';

  @override
  String get confirmPaycifBalance => 'Paycif 余额';

  @override
  String get confirmPayingTo => '正在支付给';

  @override
  String get confirmFindingBestRoute => '正在寻找最佳路径...';

  @override
  String get confirmOptimizedRoute => '优化路径';

  @override
  String get confirmAmount => '金额';

  @override
  String get confirmFee => '手续费';

  @override
  String get confirmSwipeToPay => '向右滑动支付';

  @override
  String get confirmProcessing => '处理中...';

  @override
  String topUpPayAmount(String amount) {
    return '支付 ฿$amount';
  }

  @override
  String get topUpCardNumber => '卡号';

  @override
  String get topUpExpiry => '有效期';

  @override
  String get topUpCVV => 'CVV';

  @override
  String get topUpNameOnCard => '持卡人姓名';

  @override
  String get topUpPayNow => '立即支付';

  @override
  String get topUpTestCardHint => '测试卡：4242 4242... (任何未来日期)';

  @override
  String get biometricLabel => '生物识别';

  @override
  String get biometricSettingsUpdated => '生物识别设置已更新';

  @override
  String get biometricNotAvailable => '此设备不支持生物识别';

  @override
  String get biometricNotEnrolled => '未注册生物识别。请在设备设置中进行设置。';

  @override
  String get biometricConfirmManage => '请确认以管理生物识别设置';

  @override
  String get kycStatusVerified => '已验证';

  @override
  String get kycStatusPending => '待验证';

  @override
  String get kycStatusUnverified => '未验证';

  @override
  String get aboutApp => '关于';

  @override
  String get termsOfService => '服务条款';

  @override
  String get privacyPolicy => '隐私政策';

  @override
  String get signOutConfirmTitle => '退出登录';

  @override
  String get signOutConfirmMessage => '确定要退出登录吗？';

  @override
  String get helpSearchHint => '搜索帮助...';

  @override
  String get helpNoResults => '未找到结果';

  @override
  String get helpStillNeedHelp => '还需要帮助？';

  @override
  String get helpContactTeam => '我们的支持团队全天候为您服务';

  @override
  String get helpWalletTitle => '钱包和余额';

  @override
  String get helpWalletQ1 => '如何给钱包充值？';

  @override
  String get helpWalletA1 => '您可以使用信用卡/借记卡或银行转账充值。前往首页 > 充值并选择您喜欢的方式。';

  @override
  String get helpWalletQ2 => '最大余额限额是多少？';

  @override
  String get helpWalletA2 => '限额取决于您的验证级别。已验证用户最高可持有฿500,000，未验证用户限额为฿50,000。';

  @override
  String get helpWalletQ3 => '充值需要多长时间？';

  @override
  String get helpWalletA3 => '卡片充值即时到账。银行转账通常需要1-2个工作小时。';

  @override
  String get helpPaymentTitle => '支付和转账';

  @override
  String get helpPaymentQ1 => '如何扫描二维码支付？';

  @override
  String get helpPaymentA1 => '点击导航栏中央的扫描按钮，将相机对准二维码即可。';

  @override
  String get helpPaymentQ2 => '有交易手续费吗？';

  @override
  String get helpPaymentA2 => '二维码支付和Paycif用户间转账免手续费。部分充值方式可能收取少量费用。';

  @override
  String get helpPaymentQ3 => '每日交易限额是多少？';

  @override
  String get helpPaymentA3 => '已验证用户每日限额฿200,000，未验证用户限额฿20,000。';

  @override
  String get helpSecurityTitle => '安全与隐私';

  @override
  String get helpSecurityQ1 => '我的钱安全吗？';

  @override
  String get helpSecurityA1 => '是的。您的资金受银行级加密保护，并存储在受监管的合作银行中。';

  @override
  String get helpSecurityQ2 => '如何启用生物识别登录？';

  @override
  String get helpSecurityA2 => '前往个人资料 > 账户安全 > 生物识别并开启。';

  @override
  String get helpCardTitle => '卡片和支付方式';

  @override
  String get helpCardQ1 => '支持哪些卡片？';

  @override
  String get helpCardA1 => '我们支持Visa、Mastercard、JCB和American Express。';

  @override
  String get helpCardQ2 => '如何删除已保存的卡片？';

  @override
  String get helpCardA2 => '前往支付 > 向左滑动卡片或点击菜单图标 > 删除。';

  @override
  String get supportHeaderTitle => '我们随时为您服务';

  @override
  String get supportHeaderSubtitle => '通常在2小时内回复';

  @override
  String get supportSelectCategory => '您需要什么帮助？';

  @override
  String get supportCategoryGeneral => '一般问题';

  @override
  String get supportCategoryPayment => '支付';

  @override
  String get supportCategoryAccount => '账户';

  @override
  String get supportCategoryTechnical => '技术支持';

  @override
  String get supportSubject => '主题';

  @override
  String get supportSubjectHint => '简要描述您的问题';

  @override
  String get supportMessage => '消息';

  @override
  String get supportMessageHint => '请详细描述您的问题。如有相关交易ID请一并提供。';

  @override
  String get supportMessageMinLength => '请提供更多详情（至少20个字符）';

  @override
  String get supportSubmit => '提交请求';

  @override
  String get supportTicketSubmitted => '支持工单已提交。我们将在24小时内回复。';

  @override
  String get supportAlternativeContact => '或直接联系我们';

  @override
  String get termsLastUpdated => '最后更新：2026年1月';

  @override
  String get termsSection1Title => '1. 接受条款';

  @override
  String get termsSection1Content => '使用Paycif服务即表示您同意受本服务条款的约束。';

  @override
  String get termsSection2Title => '2. 账户注册';

  @override
  String get termsSection2Content => '您必须年满18周岁才能创建账户。您有责任维护账户凭据的机密性。';

  @override
  String get termsSection3Title => '3. 支付服务';

  @override
  String get termsSection3Content => 'Paycif提供数字钱包和支付服务。除非另有说明，所有交易均不可撤销。';

  @override
  String get termsSection4Title => '4. 禁止活动';

  @override
  String get termsSection4Content => '您不得将Paycif用于非法活动、洗钱、欺诈或任何违反适用法律的目的。';

  @override
  String get termsSection5Title => '5. 责任限制';

  @override
  String get termsSection5Content => 'Paycif不对因使用我们服务而产生的任何间接、附带或后果性损害承担责任。';

  @override
  String get termsSection6Title => '6. 适用法律';

  @override
  String get termsSection6Content => '本条款受泰国法律管辖。任何争议应通过在曼谷的仲裁解决。';

  @override
  String get termsContact => '条款相关问题请联系：legal@paycif.com';

  @override
  String get privacyLastUpdated => '最后更新：2026年1月';

  @override
  String get privacyHighlightsTitle => '隐私保护要点';

  @override
  String get privacyHighlight1 => '我们绝不会将您的个人数据出售给第三方';

  @override
  String get privacyHighlight2 => '您的支付数据采用端到端加密';

  @override
  String get privacyHighlight3 => '您可以随时要求删除您的数据';

  @override
  String get privacyHighlight4 => '我们只收集服务所需的数据';

  @override
  String get privacySection1Title => '我们收集的信息';

  @override
  String get privacySection1Content =>
      '我们收集您直接提供的信息：姓名、电子邮件、电话号码、用于验证的身份证件和支付信息。我们还收集交易历史和应用分析等使用数据。';

  @override
  String get privacySection2Title => '我们如何使用您的信息';

  @override
  String get privacySection2Content =>
      '我们使用您的信息来提供和改进服务、处理交易、验证身份、预防欺诈，以及就您的账户和促销活动与您沟通。';

  @override
  String get privacySection3Title => '信息共享';

  @override
  String get privacySection3Content =>
      '我们与支付处理商和银行共享信息以完成交易，与监管机构共享法律要求的信息，与服务提供商在严格保密协议下共享信息。';

  @override
  String get privacySection4Title => '数据安全';

  @override
  String get privacySection4Content =>
      '我们对所有敏感数据实施银行级加密（AES-256）。我们的系统定期接受第三方安全公司的审计。';

  @override
  String get privacySection5Title => '您的权利';

  @override
  String get privacySection5Content =>
      '您有权访问、更正或删除您的个人数据。您可以选择退出营销通讯。您可以请求以可移植格式获取您的数据副本。';

  @override
  String get privacyContactTitle => '隐私咨询';

  @override
  String get privacyContactContent => '如果您对我们的隐私做法有疑问或希望行使您的数据权利，请联系我们的数据保护官：';
}
