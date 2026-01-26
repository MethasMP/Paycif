// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'Paycif';

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
  String get profileTitle => '프로필 설정';

  @override
  String get passportLabel => 'PASSPORT';

  @override
  String get accountSecurity => '계정 보안';

  @override
  String get biometricLogin => '생체 인증 로그인';

  @override
  String get changePin => 'PIN 변경';

  @override
  String get linkedDevices => '연결된 기기';

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
  String get contactSupport => '지원팀 문의';

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
  String get paymentEmptyTitle => '등록된 결제 수단이 없습니다';

  @override
  String get paymentEmptyDesc => '결제 수단을 추가하면 모든 거래에 대해 최적의 옵션을 자동으로 선택해 드립니다.';

  @override
  String get paymentChangeMethod => '결제 수단 변경 (필요 시)';

  @override
  String get paymentHideOptions => '다른 옵션 숨기기';

  @override
  String get sheetAddPayment => '결제 수단 추가';

  @override
  String get sheetCreditCard => '신용/직불 카드';

  @override
  String get sheetCreditCardDesc => 'Visa, Mastercard, JCB, Amex';

  @override
  String get sheetTopUp => 'Paycif 잔액 충전';

  @override
  String get sheetTopUpDesc => '은행 이체 또는 PromptPay 이용';

  @override
  String get sheetDigitalWallet => '디지털 지갑 연결';

  @override
  String get sheetDigitalWalletDesc => 'PayPal, Alipay, WeChat Pay';

  @override
  String get commonEnabled => '활성화';

  @override
  String get commonDisabled => '비활성화';

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
  String get commonGotIt => '확인';

  @override
  String get commonRequired => '필수';

  @override
  String get commonInvalid => '유효하지 않음';

  @override
  String get commonValidationFailed => '강조 표시된 필드를 확인하십시오.';

  @override
  String get commonForgotPin => 'Forgot PIN?';

  @override
  String get commonDefault => '기본';

  @override
  String get commonEdit => '편집';

  @override
  String get commonDone => '완료';

  @override
  String get commonContinue => '계속';

  @override
  String get commonNext => '다음';

  @override
  String get commonConfirm => '확인';

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
  String get homeWorldMember => 'WORLD MEMBER';

  @override
  String get homePaycifPremier => 'Paycif PREMIER';

  @override
  String get homeRecentTransactions => '최근 거래';

  @override
  String get homeViewAll => '모두 보기';

  @override
  String get homeNoTransactions => '거래 내역이 없습니다';

  @override
  String get homeNoTransactionsDesc => '카드를 사용하기 시작하면 금융 활동 내역이 여기에 표시됩니다.';

  @override
  String get historyTitle => '활동 내역';

  @override
  String get historyNoActivity => '활동 내역 없음';

  @override
  String get scanTitle => 'QR 스캔';

  @override
  String get scanErrorCamera => '카메라 오류';

  @override
  String get scanGuideTitle => 'Thai QR 결제 가이드';

  @override
  String get scanGuidePromptPayTitle => 'PromptPay란?';

  @override
  String get scanGuidePromptPayDesc => '태국의 국가 모바일 결제 시스템입니다.';

  @override
  String get scanGuideSafeTitle => '안전한가요?';

  @override
  String get scanGuideSafeDesc => '네! 모든 거래는 실시간으로 검증됩니다.';

  @override
  String get scanGuideCurrencyTitle => '통화 안내';

  @override
  String get scanGuideCurrencyDesc => '바트화와 USD 가격을 동시에 제공합니다.';

  @override
  String get scanPaymentSuccess => '결제 성공!';

  @override
  String get scanNoQrFound => 'QR 코드를 찾을 수 없습니다';

  @override
  String get topUpTitle => '잔액 충전';

  @override
  String get topUpAmountLabel => '충전 금액';

  @override
  String get topUpEnterAmount => '금액을 입력해 주세요';

  @override
  String get topUpPreviewTitle => '충전 후 예상 잔액';

  @override
  String get topUpPreviewSubtitle => '추가 예정';

  @override
  String get topUpTrustSecured => '보안 보호';

  @override
  String get topUpTrustNoFees => '수수료 없음';

  @override
  String get topUpTrustInstant => '즉시 반영';

  @override
  String get cardTitle => '카드 추가';

  @override
  String get cardNumber => '카드 번호';

  @override
  String get cardInvalidNumber => '유효하지 않은 카드 번호입니다';

  @override
  String get cardInvalidLuhn => '유효하지 않은 카드 번호입니다 (Luhn 체크 실패)';

  @override
  String get cardExpiry => '유효 기간';

  @override
  String get cardExpiryHint => 'MM/YY';

  @override
  String get cardInvalidDate => '유효하지 않은 날짜입니다';

  @override
  String get cardInvalidMonth => '월은 01-12 사이여야 합니다';

  @override
  String get cardExpired => '만료된 카드입니다';

  @override
  String get cardUseMMYY => 'MM/YY 형식을 사용해 주세요';

  @override
  String get cardCVV => 'CVV';

  @override
  String get cardInvalidCVV => '유효하지 않은 CVV';

  @override
  String get cardHolder => '카드 소유자 이름';

  @override
  String get cardHolderHint => 'KIM CHEOL SU';

  @override
  String get cardAddedSuccess => '카드가 성공적으로 추가되었습니다';

  @override
  String get cardPreviewTitle => 'Premium Card';

  @override
  String get cardPreviewHolder => 'CARD HOLDER';

  @override
  String get cardPreviewExpires => 'EXPIRES';

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
  String get confirmPaymentSuccess => '결제 완료';

  @override
  String get confirmMyWallet => '내 지갑';

  @override
  String get walletZeroFees => '수수료 무료';

  @override
  String get walletInstantTransfer => '즉시 종료';

  @override
  String get walletReliablePayment => '안전 결제';

  @override
  String get walletPaymentMethod => '결제 수단';

  @override
  String get scanUnknownRecipient => '알 수 없는 수신자';

  @override
  String get profileGuestUser => '게스트 사용자';

  @override
  String get noInternetTitle => '연결 없음';

  @override
  String get noInternetMessage => '인터넷 연결 상태를 확인해 주세요';

  @override
  String get noInternetRetry => '재시도';

  @override
  String get splashLoading => '서비스에 연결 중...';

  @override
  String get paymentSuccessTitle => '결제 성공!';

  @override
  String get commonSomethingWentWrong => '문제가 발생했습니다.';

  @override
  String get transactionDetailsTitle => '거래 상세';

  @override
  String get transactionHelp => '이 거래에 대해 도움이 필요하신가요?';

  @override
  String get loginAppleComingSoon => 'Apple ID 로그인은 곧 준비될 예정입니다';

  @override
  String get commonSessionExpired => '세션이 만료되었습니다';

  @override
  String get commonLogIn => '로그인';

  @override
  String get topUpEnterAmountError => '금액을 입력해 주세요';

  @override
  String get confirmPaymentFailed => '결제 실패';

  @override
  String get commonOk => '확인';

  @override
  String get errorCardInvalid => '카드 정보가 올바르지 않습니다. 확인 후 다시 시도하십시오.';

  @override
  String get errorInsufficientFunds => '계좌에 잔액이 부족합니다.';

  @override
  String get errorProcessingFailed => '결제를 처리할 수 없습니다. 나중에 다시 시도하십시오.';

  @override
  String get errorConnectionFailed => '연결 오류. 인터넷을 확인하고 다시 시도하십시오.';

  @override
  String get errorUnknown => '문제가 발생했습니다. 나중에 다시 시도하십시오.';

  @override
  String get errorAuthenticationFailed => '인증에 실패했습니다. 다시 시도하십시오.';

  @override
  String get errorExpiredCard => '만료된 카드입니다. 다른 카드를 사용하십시오.';

  @override
  String get errorBrandNotSupported => '이 카드 브랜드는 아직 지원되지 않습니다.';

  @override
  String get paymentFailedSetDefault => '기본 수단 설정 실패';

  @override
  String get cardDeleteTitle => '카드 삭제';

  @override
  String get commonDelete => '삭제하기';

  @override
  String get cardDeleteSuccess => '카드가 성공적으로 삭제되었습니다';

  @override
  String cardDeleteConfirm(String lastDigits) {
    return '끝자리가 $lastDigits인 카드를 삭제하시겠습니까?';
  }

  @override
  String get paymentSettingsTitle => '결제 설정';

  @override
  String get paymentPayWithApple => 'Apple Pay로 결제';

  @override
  String paymentPayWith(String method) {
    return '$method(으)로 결제';
  }

  @override
  String get transactionReceivedFrom => '받은 사람:';

  @override
  String get transactionPaidTo => '보낼 사람:';

  @override
  String get transactionMerchantPayment => '가맹점 결제';

  @override
  String get transactionTopUpLabel => '충전';

  @override
  String get transactionStatus => '상태';

  @override
  String get transactionStatusCompleted => '완료';

  @override
  String get transactionTime => '시간';

  @override
  String get transactionId => '거래 ID';

  @override
  String get transactionMethod => '결제 방식';

  @override
  String get transactionBankTransfer => '은행 이체';

  @override
  String get transactionPaycifWallet => 'Paycif 지갑';

  @override
  String get transactionSupportTicketCreated => '지원 티켓이 생성되었습니다. 곧 연락드리겠습니다.';

  @override
  String confirmReason(String amount) {
    return '฿$amount 결제 확정';
  }

  @override
  String confirmAuthFailed(String error) {
    return '인증 실패: $error';
  }

  @override
  String confirmPaymentTo(String recipient) {
    return '$recipient(으)로 결제';
  }

  @override
  String get confirmAmountToPay => '결제 금액';

  @override
  String get confirmAmountSetByMerchant => '판매자 설정 금액';

  @override
  String get confirmPayWith => '결제 수단';

  @override
  String get confirmPaycifBalance => 'Paycif 잔액';

  @override
  String get confirmPayingTo => '결제 대상';

  @override
  String get confirmFindingBestRoute => '최적 경로 찾는 중...';

  @override
  String get confirmOptimizedRoute => '최적화된 경로';

  @override
  String get confirmAmount => '금액';

  @override
  String get confirmFee => '수수료';

  @override
  String get confirmSwipeToPay => '밀어서 결제';

  @override
  String get confirmProcessing => '처리 중...';

  @override
  String topUpPayAmount(String amount) {
    return '฿$amount 결제';
  }

  @override
  String get topUpCardNumber => '카드 번호';

  @override
  String get topUpExpiry => '유효 기간';

  @override
  String get topUpCVV => 'CVV';

  @override
  String get topUpNameOnCard => '카드 소유자 이름';

  @override
  String get topUpPayNow => '지금 결제';

  @override
  String get topUpTestCardHint => '테스트 카드: 4242 4242... (미래의 날짜)';

  @override
  String get biometricLabel => '생체 인증';

  @override
  String get biometricSettingsUpdated => '생체 인증 설정이 업데이트되었습니다';

  @override
  String get biometricNotAvailable => '이 기기에서는 생체 인증을 사용할 수 없습니다';

  @override
  String get biometricNotEnrolled => '등록된 생체 정보가 없습니다. 기기 설정에서 등록해주세요.';

  @override
  String get biometricConfirmManage => '생체 인증 설정을 관리하려면 확인하세요';

  @override
  String get kycStatusVerified => '인증됨';

  @override
  String get kycStatusPending => '확인 중';

  @override
  String get kycStatusUnverified => '미인증';

  @override
  String get aboutApp => '앱 정보';

  @override
  String get termsOfService => '이용약관';

  @override
  String get privacyPolicy => '개인정보 처리방침';

  @override
  String get signOutConfirmTitle => '로그아웃';

  @override
  String get signOutConfirmMessage => '로그아웃 하시겠습니까?';

  @override
  String get helpSearchHint => '도움말 검색...';

  @override
  String get helpNoResults => '결과를 찾을 수 없습니다';

  @override
  String get helpStillNeedHelp => '아직 도움이 필요하신가요?';

  @override
  String get helpContactTeam => '지원팀이 24시간 대기하고 있습니다';

  @override
  String get helpWalletTitle => '지갑 & 잔액';

  @override
  String get helpWalletQ1 => '지갑을 충전하려면?';

  @override
  String get helpWalletA1 => '신용/체크카드 또는 계좌이체로 충전할 수 있습니다. 홈 > 충전에서 선택하세요.';

  @override
  String get helpWalletQ2 => '최대 잔액 한도는?';

  @override
  String get helpWalletA2 =>
      '한도는 인증 레벨에 따라 다릅니다. 인증 사용자는 ฿500,000까지, 미인증 사용자는 ฿50,000까지입니다.';

  @override
  String get helpWalletQ3 => '충전에 걸리는 시간은?';

  @override
  String get helpWalletA3 => '카드 충전은 즉시 반영됩니다. 계좌이체는 보통 1-2 영업시간이 소요됩니다.';

  @override
  String get helpPaymentTitle => '결제 & 송금';

  @override
  String get helpPaymentQ1 => 'QR 코드로 결제하려면?';

  @override
  String get helpPaymentA1 => '네비게이션 바 중앙의 스캔 버튼을 탭하고 QR 코드에 카메라를 향하세요.';

  @override
  String get helpPaymentQ2 => '수수료가 있나요?';

  @override
  String get helpPaymentA2 =>
      'QR 결제와 Paycif 사용자 간 송금은 무료입니다. 일부 충전 방법에는 수수료가 있을 수 있습니다.';

  @override
  String get helpPaymentQ3 => '일일 거래 한도는?';

  @override
  String get helpPaymentA3 => '인증 사용자는 하루 ฿200,000까지, 미인증 사용자는 ฿20,000까지입니다.';

  @override
  String get helpSecurityTitle => '보안 & 개인정보';

  @override
  String get helpSecurityQ1 => '돈이 안전한가요?';

  @override
  String get helpSecurityA1 => '네. 은행급 암호화로 보호되며 규제된 파트너 은행에 보관됩니다.';

  @override
  String get helpSecurityQ2 => '생체 인증을 활성화하려면?';

  @override
  String get helpSecurityA2 => '프로필 > 계정 보안 > 생체 인증을 켜세요.';

  @override
  String get helpCardTitle => '카드 & 결제 수단';

  @override
  String get helpCardQ1 => '지원되는 카드는?';

  @override
  String get helpCardA1 => 'Visa, Mastercard, JCB, American Express를 지원합니다.';

  @override
  String get helpCardQ2 => '저장된 카드를 삭제하려면?';

  @override
  String get helpCardA2 => '결제 > 카드를 왼쪽으로 스와이프하거나 메뉴 아이콘 > 삭제를 선택하세요.';

  @override
  String get supportHeaderTitle => '언제든 도와드리겠습니다';

  @override
  String get supportHeaderSubtitle => '보통 2시간 내에 응답합니다';

  @override
  String get supportSelectCategory => '어떤 도움이 필요하신가요?';

  @override
  String get supportCategoryGeneral => '일반';

  @override
  String get supportCategoryPayment => '결제';

  @override
  String get supportCategoryAccount => '계정';

  @override
  String get supportCategoryTechnical => '기술 지원';

  @override
  String get supportSubject => '제목';

  @override
  String get supportSubjectHint => '문제에 대한 간단한 설명';

  @override
  String get supportMessage => '메시지';

  @override
  String get supportMessageHint => '문제를 상세히 설명해 주세요. 관련 거래 ID가 있다면 포함해 주세요.';

  @override
  String get supportMessageMinLength => '자세한 내용을 입력해 주세요 (최소 20자)';

  @override
  String get supportSubmit => '요청 제출';

  @override
  String get supportTicketSubmitted => '지원 티켓이 접수되었습니다. 24시간 내에 응답 드리겠습니다.';

  @override
  String get supportAlternativeContact => '또는 직접 연락하세요';

  @override
  String get termsLastUpdated => '최종 업데이트: 2026년 1월';

  @override
  String get termsSection1Title => '1. 이용약관 동의';

  @override
  String get termsSection1Content =>
      'Paycif 서비스를 이용하시면 본 이용약관에 동의하신 것으로 간주됩니다.';

  @override
  String get termsSection2Title => '2. 계정 등록';

  @override
  String get termsSection2Content =>
      '계정을 만들려면 만 18세 이상이어야 합니다. 계정 자격 증명의 기밀성을 유지할 책임이 있습니다.';

  @override
  String get termsSection3Title => '3. 결제 서비스';

  @override
  String get termsSection3Content =>
      'Paycif는 디지털 지갑 및 결제 서비스를 제공합니다. 거래는 원칙적으로 취소 불가능합니다.';

  @override
  String get termsSection4Title => '4. 금지 활동';

  @override
  String get termsSection4Content =>
      '불법 활동, 자금 세탁, 사기 또는 관련 법률을 위반하는 목적으로 Paycif를 사용할 수 없습니다.';

  @override
  String get termsSection5Title => '5. 책임 제한';

  @override
  String get termsSection5Content =>
      'Paycif는 서비스 사용으로 인한 간접적, 부수적 또는 결과적 손해에 대해 책임지지 않습니다.';

  @override
  String get termsSection6Title => '6. 준거법';

  @override
  String get termsSection6Content =>
      '본 약관은 태국 법률의 적용을 받습니다. 분쟁은 방콕에서 중재를 통해 해결됩니다.';

  @override
  String get termsContact => '약관에 관한 문의: legal@paycif.com';

  @override
  String get privacyLastUpdated => '최종 업데이트: 2026년 1월';

  @override
  String get privacyHighlightsTitle => '개인정보 보호 요약';

  @override
  String get privacyHighlight1 => '개인 데이터를 제3자에게 판매하지 않습니다';

  @override
  String get privacyHighlight2 => '결제 데이터는 종단간 암호화됩니다';

  @override
  String get privacyHighlight3 => '언제든 데이터 삭제를 요청할 수 있습니다';

  @override
  String get privacyHighlight4 => '서비스에 필요한 데이터만 수집합니다';

  @override
  String get privacySection1Title => '수집하는 정보';

  @override
  String get privacySection1Content =>
      '이름, 이메일, 전화번호, 신원 확인을 위한 신분증, 결제 정보를 수집합니다. 거래 내역과 앱 분석 데이터도 수집합니다.';

  @override
  String get privacySection2Title => '정보 사용 방법';

  @override
  String get privacySection2Content =>
      '서비스 제공 및 개선, 거래 처리, 신원 확인, 사기 방지, 계정 관련 연락에 사용합니다.';

  @override
  String get privacySection3Title => '정보 공유';

  @override
  String get privacySection3Content =>
      '거래 완료를 위해 결제 처리업체 및 은행과, 법적 요구에 따라 규제 당국과, 엄격한 기밀 유지 계약 하에 서비스 제공업체와 공유합니다.';

  @override
  String get privacySection4Title => '데이터 보안';

  @override
  String get privacySection4Content =>
      '모든 민감한 데이터에 AES-256 암호화를 적용합니다. 시스템은 제3자 보안 기관의 정기 감사를 받습니다.';

  @override
  String get privacySection5Title => '귀하의 권리';

  @override
  String get privacySection5Content =>
      '개인 데이터에 대한 접근, 수정 또는 삭제를 요청할 권리가 있습니다. 마케팅 커뮤니케이션을 거부할 수 있습니다.';

  @override
  String get privacyContactTitle => '개인정보 문의';

  @override
  String get privacyContactContent =>
      '개인정보 보호 관행에 대한 질문이나 데이터 권리 행사를 원하시면 데이터 보호 담당자에게 연락하세요:';
}
