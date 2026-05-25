class MRZUtils {
  /// Calculates the check digit for a string according to ICAO 9303 standards.
  /// It uses the 7-3-1 weighting system.
  static int calculateChecksum(String data) {
    const weights = [7, 3, 1];
    int sum = 0;

    for (int i = 0; i < data.length; i++) {
      final codeUnit = data.codeUnitAt(i);
      int val = 0;

      if (codeUnit >= 48 && codeUnit <= 57) {
        // '0'-'9'
        val = codeUnit - 48;
      } else if (codeUnit >= 65 && codeUnit <= 90) {
        // 'A'-'Z'
        val = codeUnit - 65 + 10;
      } else {
        // '<' and other fillers are 0
        val = 0;
      }

      sum += val * weights[i % 3];
    }

    return sum % 10;
  }
}
