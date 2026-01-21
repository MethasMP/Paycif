enum QRType {
  static, // 11: Reusable, Amount optional
  dynamic, // 12: One-time, Amount usually mandatory
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
  });
}

class EMVCoParser {
  // static const String _crcTag = '63'; // Unused for now as we hardcode '6304' check

  /// Parses a raw EMVCo string into a structured object
  static EMFData parse(String raw) {
    if (raw.isEmpty) return _empty();

    final tags = _parseTLV(raw);

    // 1. Validate CRC (Tag 63)
    bool isValid = _validateCRC(raw);

    // 2. Extract Basic Info
    final merchantName = tags['59'] ?? 'Unknown Merchant';
    final merchantCity = tags['60'];

    // 3. Extract Amount (Tag 54)
    double? amount;
    if (tags['54'] != null) {
      amount = double.tryParse(tags['54']!);
    }

    // 4. Extract Point of Initiation Method (Tag 01)
    // 11 = Static (Reusable), 12 = Dynamic (One-time)
    QRType type = QRType.unknown;
    if (tags['01'] == '11') type = QRType.static;
    if (tags['01'] == '12') type = QRType.dynamic;

    // 5. Extract PromptPay ID (Tag 29 or 30 usually)
    // AID: A000000677010111 -> Tag 29, Subtag 00
    // Simplified search for PromptPay ID in Tag 29 (Credit Transfer)
    String? promptPayId = _extractPromptPayID(tags);

    return EMFData(
      rawTags: tags,
      merchantName: merchantName,
      merchantCity: merchantCity,
      amount: amount,
      currencyCode: tags['53'] ?? '764', // Default to THB if missing
      isValid: isValid,
      rawValue: raw,
      type: type,
      promptPayId: promptPayId,
    );
  }

  static Map<String, String> _parseTLV(String raw) {
    final Map<String, String> tags = {};
    int index = 0;
    while (index < raw.length) {
      // ID (2 chars)
      if (index + 2 > raw.length) break;
      final id = raw.substring(index, index + 2);
      index += 2;

      // Length (2 chars)
      if (index + 2 > raw.length) break;
      final lenStr = raw.substring(index, index + 2);
      index += 2;

      final len = int.tryParse(lenStr);
      if (len == null) break;

      // Value
      if (index + len > raw.length) break;
      final value = raw.substring(index, index + len);
      tags[id] = value;

      index += len;
    }
    return tags;
  }

  static bool _validateCRC(String raw) {
    // CRC is usually the last tag '63' length '04'
    // Calculate CRC of string up to the value of tag 63
    try {
      if (!raw.contains('6304')) return false;

      final splitIndex = raw.lastIndexOf('6304');
      if (splitIndex == -1) return false;

      final dataToVerify = raw.substring(0, splitIndex + 4); // Include '6304'
      final targetCrc = raw.substring(splitIndex + 4);

      if (targetCrc.length != 4) return false;

      final calculatedCrc = _calculateCRC16(dataToVerify);
      return calculatedCrc.toUpperCase() == targetCrc.toUpperCase();
    } catch (e) {
      return false;
    }
  }

  static String _calculateCRC16(String data) {
    int crc = 0xFFFF; // Initial value
    for (int i = 0; i < data.length; i++) {
      int x = ((crc >> 8) ^ data.codeUnitAt(i)) & 0xFF;
      x ^= x >> 4;
      crc = ((crc << 8) ^ (x << 12) ^ (x << 5) ^ x) & 0xFFFF;
    }
    return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  }

  static String? _extractPromptPayID(Map<String, String> tags) {
    // Check Tag 29 (Merchant Account Information)
    if (tags.containsKey('29')) {
      final subTags = _parseTLV(tags['29']!);
      // AID for PromptPay is usually in subtag 00 with value A000000677...
      if (subTags['00']?.startsWith('A000000677') == true) {
        // Tag 01 is usually the Mobile No or Tax ID
        return subTags['01'];
      }
    }
    return null;
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
