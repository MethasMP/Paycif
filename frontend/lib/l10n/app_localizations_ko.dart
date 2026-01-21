// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'ZapPay';

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
  String get biometricLogin => '생체 인증 로그인';

  @override
  String get changePin => 'PIN 변경';

  @override
  String get linkedDevices => '연결된 기기';

  @override
  String get preferences => '설정';

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
  String get helpCenter => '고객센터';

  @override
  String get contactSupport => '지원팀 문의';

  @override
  String get signOut => '로그아웃';

  @override
  String get version => '버전';

  @override
  String get paymentStatus => '결제 상태';

  @override
  String get paymentReady => '준비됨';

  @override
  String get paymentReliable => '안전함';

  @override
  String get paymentInstant => '즉시';

  @override
  String get paymentNoFees => '수수료 없음';

  @override
  String get paymentAddMethod => '결제 수단 추가';

  @override
  String get paymentEmptyTitle => '결제 수단 없음';

  @override
  String get paymentEmptyDesc =>
      '결제 수단을 추가하면, 모든 거래에 대해 최적의 옵션을 자동으로 선택해 드립니다.';

  @override
  String get paymentChangeMethod => '결제 수단 변경 (필요 시)';

  @override
  String get paymentHideOptions => '옵션 숨기기';

  @override
  String get sheetAddPayment => '결제 수단 추가';

  @override
  String get sheetCreditCard => '신용/직불 카드';

  @override
  String get sheetCreditCardDesc => 'Visa, Mastercard, JCB, Amex';

  @override
  String get sheetTopUp => 'ZapPay 잔액 충전';

  @override
  String get sheetTopUpDesc => '계좌 이체 / PromptPay';

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
}
