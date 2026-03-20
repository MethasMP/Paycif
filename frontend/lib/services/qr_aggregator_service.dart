import '../utils/emv_parser.dart';

enum PaymentMethodType {
  promptPay,
  billPayment,
  truemoney,
  shopeePay,
  other,
}

class PaymentContext {
  final String title;
  final String subtitle;
  final String? accountId; // Mobile, TaxID, or E-Wallet
  final String? billerId;
  final String? reference1;
  final String? reference2;
  final double? amount;
  final String currency;
  final PaymentMethodType method;
  final Map<String, String> metadata;
  final bool isSafe;

  PaymentContext({
    required this.title,
    required this.subtitle,
    this.accountId,
    this.billerId,
    this.reference1,
    this.reference2,
    this.amount,
    this.currency = 'THB',
    required this.method,
    this.metadata = const {},
    this.isSafe = true,
  });
}

class QrAggregatorService {
  /// The core IP logic to aggregate and interpret any scanned code
  static PaymentContext aggregate(String rawData) {
    // 1. Try EMVCo Parsing (The core standard)
    if (_isEMVCo(rawData)) {
      final emv = EMVCoParser.parse(rawData);
      if (emv.isValid) {
        return _fromEMV(emv);
      }
    }

    // 2. Try URL patterns (Legacy or specific providers)
    if (rawData.startsWith('http')) {
      return _fromUrl(rawData);
    }

    // 3. Fallback
    return PaymentContext(
      title: 'Unknown QR',
      subtitle: 'Raw Data detected',
      method: PaymentMethodType.other,
      metadata: {'raw': rawData},
      isSafe: false,
    );
  }

  static bool _isEMVCo(String data) {
    // EMVCo start with Tag 00 length 02 value 01
    return data.startsWith('000201');
  }

  static PaymentContext _fromEMV(EMFData emv) {
    PaymentMethodType method = PaymentMethodType.promptPay;
    String subtitle = 'PromptPay Transfer';

    if (emv.promptPayType == PromptPayType.billPayment) {
      method = PaymentMethodType.billPayment;
      subtitle = 'Bill Payment';
    }

    // --- Paycif IP: Smart Provider Detection ---
    String title = emv.merchantName;
    
    // ShopeePay / ShopeeFood detection (Biller ID 010...)
    if (emv.billerId?.startsWith('0105557112') == true) {
      method = PaymentMethodType.shopeePay;
      subtitle = 'ShopeePay Merchant';
      if (title.isEmpty || title == 'Unknown Recipient') title = 'Shopee Merchant';
    }

    // TrueMoney detection
    if (emv.promptPayId?.startsWith('0066') == false && emv.promptPayId?.length == 15) {
      method = PaymentMethodType.truemoney;
      subtitle = 'TrueMoney Wallet';
    }

    return PaymentContext(
      title: title,
      subtitle: subtitle,
      accountId: emv.promptPayId,
      billerId: emv.billerId,
      reference1: emv.reference1,
      reference2: emv.reference2,
      amount: emv.amount,
      currency: emv.currencyCode == '764' ? 'THB' : 'USD',
      method: method,
      metadata: {
        'city': emv.merchantCity ?? '',
        'type': emv.type.name,
        'raw': emv.rawValue,
      },
    );
  }

  static PaymentContext _fromUrl(String url) {
    // Logic to handle payment URLs (e.g. omise.co, etc)
    return PaymentContext(
      title: 'Web Payment',
      subtitle: url,
      method: PaymentMethodType.other,
      isSafe: true, // Should be checked against a whitelist
    );
  }
}
