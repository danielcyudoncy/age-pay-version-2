import 'package:flutter_test/flutter_test.dart';
import 'package:cls/core/constants/app_version.dart';

void main() {
  group('AppVersion semver comparison tests', () {
    test('standard patch upgrade is detected as older', () {
      expect(AppVersion.isVersionOlder('1.0.0', '1.0.1'), isTrue);
      expect(AppVersion.isVersionOlder('1.0.1', '1.0.2'), isTrue);
    });

    test('minor upgrade is detected as older', () {
      expect(AppVersion.isVersionOlder('1.0.9', '1.1.0'), isTrue);
      expect(AppVersion.isVersionOlder('1.1.0', '1.2.0'), isTrue);
    });

    test('major upgrade is detected as older', () {
      expect(AppVersion.isVersionOlder('1.9.9', '2.0.0'), isTrue);
      expect(AppVersion.isVersionOlder('0.9.0', '1.0.0'), isTrue);
    });

    test('equal versions are not older', () {
      expect(AppVersion.isVersionOlder('1.0.0', '1.0.0'), isFalse);
      expect(AppVersion.isVersionOlder('2.3.4', '2.3.4'), isFalse);
    });

    test('newer versions are not older', () {
      expect(AppVersion.isVersionOlder('1.0.1', '1.0.0'), isFalse);
      expect(AppVersion.isVersionOlder('1.2.0', '1.1.9'), isFalse);
      expect(AppVersion.isVersionOlder('2.0.0', '1.9.9'), isFalse);
    });

    test('handles two segment versions gracefully', () {
      expect(AppVersion.isVersionOlder('1.0', '1.0.1'), isTrue);
      expect(AppVersion.isVersionOlder('1.1', '1.0.9'), isFalse);
    });

    test('handles build numbers with plus syntax', () {
      expect(AppVersion.isVersionOlder('1.0.0+1', '1.0.0+2'), isTrue);
      expect(AppVersion.isVersionOlder('1.0.0+2', '1.0.0+1'), isFalse);
      expect(AppVersion.isVersionOlder('1.0.0+5', '1.0.1+1'), isTrue);
    });

    test('handles whitespace and empty strings gracefully', () {
      expect(AppVersion.isVersionOlder('', '1.0.0'), isFalse);
      expect(AppVersion.isVersionOlder('1.0.0', ''), isFalse);
      expect(AppVersion.isVersionOlder(' 1.0.0 ', ' 1.0.1 '), isTrue);
    });
  });
}
