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
  final bool
  isPersonal; // True if no Tag 59 (Merchant Name) - indicates Personal QR

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
    this.isPersonal = false,
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

    // 2. Extract PromptPay ID first (needed for fallback name)
    String? promptPayId = _extractPromptPayID(tags);

    // 3. Extract Basic Info - with Smart Fallback for Personal QR
    String merchantName = tags['59'] ?? '';
    if (merchantName.isEmpty && promptPayId != null) {
      // Personal PromptPay: Format ID as display name
      merchantName = _formatPromptPayDisplayName(promptPayId);
    } else if (merchantName.isEmpty) {
      merchantName = 'Unknown Merchant';
    }

    final merchantCity = tags['60'];

    // 4. Extract Amount (Tag 54)
    double? amount;
    if (tags['54'] != null) {
      amount = double.tryParse(tags['54']!);
    }

    // 5. Extract Point of Initiation Method (Tag 01)
    // 11 = Static (Reusable), 12 = Dynamic (One-time)
    QRType type = QRType.unknown;
    if (tags['01'] == '11') type = QRType.static;
    if (tags['01'] == '12') type = QRType.dynamic;
    // Determine if this is a Personal QR (no merchant name in QR)
    final bool isPersonal = (tags['59'] ?? '').isEmpty && promptPayId != null;

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
      isPersonal: isPersonal,
    );
  }

  /// Formats a PromptPay ID for user-friendly display
  /// Input: "0066812345678" -> Output: "PromptPay: 081-234-5678"
  /// Input: "1234567890123" (13 digits) -> Output: "PromptPay: X-XXXX-12345"
  static String _formatPromptPayDisplayName(String id) {
    // Remove country code prefix if present (0066 -> local format)
    String localId = id;
    if (id.startsWith('0066')) {
      localId = '0${id.substring(4)}';
    }

    // Format based on type
    if (localId.length == 10 && localId.startsWith('0')) {
      // Mobile Number: 0XX-XXX-XXXX (mask middle)
      return 'PromptPay: ${localId.substring(0, 3)}-XXX-${localId.substring(7)}';
    } else if (localId.length == 13) {
      // National ID: X-XXXX-XXXXX (heavy mask for privacy)
      return 'PromptPay: ${localId.substring(0, 1)}-XXXX-${localId.substring(8)}';
    } else {
      // Fallback: Just show last 4 digits
      final suffix = localId.length > 4
          ? localId.substring(localId.length - 4)
          : localId;
      return 'PromptPay: ***$suffix';
    }
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
