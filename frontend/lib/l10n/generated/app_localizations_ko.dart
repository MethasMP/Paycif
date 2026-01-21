// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'Paysif';

  @override
  String get navHome => '홈';

  @override
  String get navHistory => '내역';

  @override
  String get navPayment => '결제';

  @override
  String get navProfile => '프로필';

  @override
  String get navScan => '스캔';

  @override
  String get profileTitle => '내 프로필';

  @override
  String get passportLabel => '여권';

  @override
  String get accountSecurity => '계정 보안';

  @override
  String get biometricLogin => '생체 인식 로그인';

  @override
  String get changePin => 'PIN 변경';

  @override
  String get linkedDevices => '연동된 기기';

  @override
  String get preferences => '환경 설정';

  @override
  String get darkMode => '다크 모드';

  @override
  String get lightMode => '라이트 모드';

  @override
  String get language => '언어';

  @override
  String get notifications => '알림';

  @override
  String get support => '지원';

  @override
  String get helpCenter => '고객 센터';

  @override
  String get contactSupport => '지원팀에 문의';

  @override
  String get signOut => '로그아웃';

  @override
  String get version => '버전';

  @override
  String get paymentStatus => '결제 상태';

  @override
  String get paymentReady => '준비 완료';

  @override
  String get paymentReliable => '신뢰할 수 있음';

  @override
  String get paymentInstant => '즉시';

  @override
  String get paymentNoFees => '수수료 없음';

  @override
  String get paymentAddMethod => '결제 수단 추가';

  @override
  String get paymentEmptyTitle => '결제 수단이 없습니다';

  @override
  String get paymentEmptyDesc => '결제 수단을 추가하면 모든 거래에 대해 최적의 옵션을 자동으로 선택해 드립니다.';

  @override
  String get paymentChangeMethod => '수단 변경 (필요한 경우)';

  @override
  String get paymentHideOptions => '다른 옵션 숨기기';

  @override
  String get sheetAddPayment => '결제 수단 추가';

  @override
  String get sheetCreditCard => '신용/직불 카드';

  @override
  String get sheetCreditCardDesc => 'Visa, Mastercard, JCB, Amex';

  @override
  String get sheetTopUp => 'Paysif 잔액 충전';

  @override
  String get sheetTopUpDesc => '은행 이체 또는 PromptPay';

  @override
  String get sheetDigitalWallet => '디지털 지갑 연결';

  @override
  String get sheetDigitalWalletDesc => 'PayPal, Alipay, WeChat Pay';

  @override
  String get commonEnabled => '활성화됨';

  @override
  String get commonDisabled => '비활성화됨';

  @override
  String get commonSuccess => '성공';

  @override
  String get commonError => '오류';

  @override
  String get commonToday => '오늘';

  @override
  String get commonYesterday => '어제';

  @override
  String get commonApply => '적용';

  @override
  String get commonSave => '저장';

  @override
  String get commonCancel => '취소';

  @override
  String get commonUpload => '업로드';

  @override
  String get commonHelp => '도움말';

  @override
  String get commonGotIt => '알겠습니다!';

  @override
  String get commonRequired => '필수';

  @override
  String get commonInvalid => '유효하지 않음';

  @override
  String get homeTopUp => '충전';

  @override
  String get homeInfo => '정보';

  @override
  String get homeMore => '더보기';

  @override
  String get homeTotalBalance => '총 잔액';

  @override
  String get homeShow => '표시';

  @override
  String get homeHide => '숨기기';

  @override
  String get homeWorldMember => '월드 멤버';

  @override
  String get homePaysifPremier => 'Paysif 프리미어';

  @override
  String get homeRecentTransactions => '최근 거래';

  @override
  String get homeViewAll => '모두 보기';

  @override
  String get homeNoTransactions => '아직 거래가 없습니다';

  @override
  String get homeNoTransactionsDesc => '카드를 사용하기 시작하면 여기에 금융 활동이 표시됩니다.';

  @override
  String get historyTitle => '활동 내역';

  @override
  String get historyNoActivity => '아직 활동 없음';

  @override
  String get scanTitle => 'QR 코드 스캔';

  @override
  String get scanErrorCamera => '카메라 오류';

  @override
  String get scanGuideTitle => 'PromptPay 가이드';

  @override
  String get scanGuidePromptPayTitle => 'PromptPay란 무엇인가요?';

  @override
  String get scanGuidePromptPayDesc => '태국의 국가 모바일 결제 시스템입니다.';

  @override
  String get scanGuideSafeTitle => '안전한가요?';

  @override
  String get scanGuideSafeDesc => '네! 모든 거래는 검증됩니다.';

  @override
  String get scanGuideCurrencyTitle => '통화';

  @override
  String get scanGuideCurrencyDesc => '바트와 USD 가격을 모두 표시합니다.';

  @override
  String get scanPaymentSuccess => '결제 성공!';

  @override
  String get scanNoQrFound => '이미지에서 QR 코드를 찾을 수 없습니다';

  @override
  String get topUpTitle => '금액 추가';

  @override
  String get topUpAmountLabel => '추가할 금액';

  @override
  String get topUpEnterAmount => '금액 입력';

  @override
  String get topUpPreviewTitle => '충전 후';

  @override
  String get topUpPreviewSubtitle => '추가됩니다';

  @override
  String get topUpTrustSecured => '보안';

  @override
  String get topUpTrustNoFees => '수수료 없음';

  @override
  String get topUpTrustInstant => '즉시';

  @override
  String get cardTitle => '새 카드 추가';

  @override
  String get cardNumber => '카드 번호';

  @override
  String get cardInvalidNumber => '유효하지 않은 카드 번호';

  @override
  String get cardExpiry => '유효 기간';

  @override
  String get cardExpiryHint => 'MM/YY';

  @override
  String get cardInvalidDate => '유효하지 않음';

  @override
  String get cardUseMMYY => 'MM/YY 형식 사용';

  @override
  String get cardCVV => 'CVV';

  @override
  String get cardInvalidCVV => '유효하지 않은 CVV';

  @override
  String get cardHolder => '카드 소유자 이름';

  @override
  String get cardHolderHint => 'HONG GILDONG';

  @override
  String get cardAddedSuccess => '카드가 성공적으로 추가되었습니다';

  @override
  String get cardPreviewTitle => '프리미엄 카드';

  @override
  String get cardPreviewHolder => '카드 소유자';

  @override
  String get cardPreviewExpires => '만료일';

  @override
  String get cardAddBtn => '카드 추가';

  @override
  String get confirmTitle => '결제 확인';

  @override
  String get confirmBestOption => '최적 옵션';

  @override
  String get confirmEnterAmount => '금액 입력';

  @override
  String get confirmTotalPayment => '총 결제 금액';

  @override
  String get confirmPaymentSuccess => '결제 성공';

  @override
  String get confirmMyWallet => '내 지갑';

  @override
  String get walletZeroFees => '수수료 0원';

  @override
  String get walletInstantTransfer => '즉시 이체';

  @override
  String get walletReliablePayment => '안전 결제';

  @override
  String get walletPaymentMethod => '결제 수단';

  @override
  String get scanUnknownRecipient => '알 수 없는 수신자';

  @override
  String get profileGuestUser => '게스트 사용자';
}
