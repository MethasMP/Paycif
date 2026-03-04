import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/utils/mrz_utils.dart';

void main() {
  group('MRZUtils Checksum Tests (ICAO 9303)', () {
    test('Standard Numeric (1234567) should return 4', () {
      expect(MRZUtils.calculateChecksum('1234567'), 4);
    });

    test('Passport Number Example (A1234567<) should return 6', () {
      expect(MRZUtils.calculateChecksum('A1234567<'), 6);
    });

    test('Fillers (<<<<<) should return 0', () {
      expect(MRZUtils.calculateChecksum('<<<<<'), 0);
    });

    test(
      'Real-world Alpha Numeric mix should be consistent with Weight Sum 7-3-1',
      () {
        // T(29)*7 + H(17)*3 + A(10)*1 + I(18)*7 = 390 % 10 = 0
        expect(MRZUtils.calculateChecksum('THAI'), 0);
      },
    );
  });
}
