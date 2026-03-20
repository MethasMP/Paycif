enum QRType {
  static, // 11: Reusable, Amount optional
  dynamic, // 12: One-time, Amount usually mandatory
  unknown,
}

enum PromptPayType {
  mobile,
  taxId,
  eWallet,
  billPayment,
  unknown,
}

class EMFData {
  final Map<String, String> rawTags;
  final String merchantName;
  final String? merchantCity;
  final double? amount;
  final String currencyCode;
  final bool isValid;
  final String rawValue;
  final QRType type;
  final String? promptPayId;
  final PromptPayType promptPayType;
  final String? billerId;
  final String? reference1;
  final String? reference2;
  final bool isPersonal;

  EMFData({
    required this.rawTags,
    required this.merchantName,
    this.merchantCity,
    this.amount,
    required this.currencyCode,
    required this.isValid,
    required this.rawValue,
    required this.type,
    this.promptPayId,
    this.promptPayType = PromptPayType.unknown,
    this.billerId,
    this.reference1,
    this.reference2,
    this.isPersonal = false,
  });
}

class EMVCoParser {
  /// Parses a raw EMVCo string into a structured object
  static EMFData parse(String raw) {
    if (raw.isEmpty) return _empty();

    final tags = _parseTLV(raw);
    bool isValid = _validateCRC(raw);

    // 1. Point of Initiation Method (Tag 01)
    QRType type = QRType.unknown;
    if (tags['01'] == '11') type = QRType.static;
    if (tags['01'] == '12') type = QRType.dynamic;

    // 2. Extract Merchant Info
    String? promptPayId;
    PromptPayType ppType = PromptPayType.unknown;
    String? billerId;
    String? ref1;
    String? ref2;

    // Tag 29: PromptPay Credit Transfer
    if (tags.containsKey('29')) {
      final subTags = _parseTLV(tags['29']!);
      if (subTags['00']?.startsWith('A000000677') == true) {
        promptPayId = subTags['01'];
        ppType = _identifyPromptPayType(promptPayId);
      }
    }

    // Tag 30: Bill Payment
    if (tags.containsKey('30')) {
      final subTags = _parseTLV(tags['30']!);
      if (subTags['00']?.startsWith('A000000677') == true) {
        billerId = subTags['01'];
        ref1 = subTags['02'];
        ref2 = subTags['03'];
        ppType = PromptPayType.billPayment;
      }
    }

    // 3. Extract Display Name
    String merchantName = tags['59'] ?? '';
    final bool isPersonal = merchantName.isEmpty && promptPayId != null;

    if (merchantName.isEmpty) {
      if (ppType == PromptPayType.billPayment) {
        merchantName = 'Bill Payment: $billerId';
      } else if (promptPayId != null) {
        merchantName = _formatPromptPayDisplayName(promptPayId);
      } else {
        merchantName = 'Unknown Recipient';
      }
    }

    // 4. Amount & Currency
    double? amount;
    if (tags['54'] != null) {
      amount = double.tryParse(tags['54']!);
    }

    return EMFData(
      rawTags: tags,
      merchantName: merchantName,
      merchantCity: tags['60'],
      amount: amount,
      currencyCode: tags['53'] ?? '764',
      isValid: isValid,
      rawValue: raw,
      type: type,
      promptPayId: promptPayId,
      promptPayType: ppType,
      billerId: billerId,
      reference1: ref1,
      reference2: ref2,
      isPersonal: isPersonal,
    );
  }

  static PromptPayType _identifyPromptPayType(String? id) {
    if (id == null) return PromptPayType.unknown;
    if (id.length == 13 && id.startsWith('0066')) return PromptPayType.mobile;
    if (id.length == 13) return PromptPayType.taxId;
    if (id.length == 15) return PromptPayType.eWallet;
    if (id.length == 10 && id.startsWith('0')) return PromptPayType.mobile;
    return PromptPayType.unknown;
  }

  static String _formatPromptPayDisplayName(String id) {
    String localId = id;
    if (id.startsWith('0066')) {
      localId = '0${id.substring(4)}';
    }

    if (localId.length == 10 && localId.startsWith('0')) {
      return 'Mobile: ${localId.substring(0, 3)}-XXX-${localId.substring(7)}';
    } else if (localId.length == 13) {
      return 'ID: ${localId.substring(0, 1)}-XXXX-${localId.substring(9, 13)}';
    } else if (localId.length == 15) {
      return 'E-Wallet: ***${localId.substring(localId.length - 4)}';
    }
    return 'PromptPay: $id';
  }

  static Map<String, String> _parseTLV(String raw) {
    final Map<String, String> tags = {};
    int index = 0;
    while (index < raw.length) {
      if (index + 4 > raw.length) break;
      final id = raw.substring(index, index + 2);
      final lenStr = raw.substring(index + 2, index + 4);
      final len = int.tryParse(lenStr);
      if (len == null || index + 4 + len > raw.length) break;
      tags[id] = raw.substring(index + 4, index + 4 + len);
      index += 4 + len;
    }
    return tags;
  }

  static bool _validateCRC(String raw) {
    if (raw.length < 8) return false;
    final data = raw.substring(0, raw.length - 4);
    final expectedCrc = raw.substring(raw.length - 4).toUpperCase();
    final calculatedCrc = _calculateCRC16(data);
    return calculatedCrc == expectedCrc;
  }

  static String _calculateCRC16(String data) {
    int crc = 0xFFFF;
    for (int i = 0; i < data.length; i++) {
      int x = ((crc >> 8) ^ data.codeUnitAt(i)) & 0xFF;
      x ^= x >> 4;
      crc = ((crc << 8) ^ (x << 12) ^ (x << 5) ^ x) & 0xFFFF;
    }
    return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  }

  static EMFData _empty() {
    return EMFData(
      rawTags: {},
      merchantName: 'Unknown',
      currencyCode: '764',
      isValid: false,
      rawValue: '',
      type: QRType.unknown,
    );
  }
}

