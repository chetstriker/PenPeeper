import 'package:flutter_test/flutter_test.dart';
import 'package:penpeeper/utils/platform/platform_utils.dart';

void main() {
  group('PlatformUtils platform detection', () {
    test('should detect platform type', () {
      expect(PlatformUtils.isWeb || PlatformUtils.isDesktop, true);
      expect(PlatformUtils.isWeb, !PlatformUtils.isDesktop);
    });

    test('should return valid platform name', () {
      final name = PlatformUtils.platformName;
      expect(['Web', 'Windows', 'Linux', 'macOS', 'Unknown'].contains(name), true);
    });
  });

  group('PlatformUtils.platformSpecific', () {
    test('should execute correct platform code', () async {
      final result = await PlatformUtils.platformSpecific(
        web: () async => 'web-result',
        desktop: () async => 'desktop-result',
      );
      
      if (PlatformUtils.isWeb) {
        expect(result, 'web-result');
      } else {
        expect(result, 'desktop-result');
      }
    });

    test('should handle async operations', () async {
      final result = await PlatformUtils.platformSpecific(
        web: () async {
          await Future.delayed(Duration(milliseconds: 1));
          return 42;
        },
        desktop: () async {
          await Future.delayed(Duration(milliseconds: 1));
          return 99;
        },
      );
      
      expect(result, isA<int>());
      expect(result, PlatformUtils.isWeb ? 42 : 99);
    });
  });

  group('PlatformUtils.platformSpecificSync', () {
    test('should execute correct platform code synchronously', () {
      final result = PlatformUtils.platformSpecificSync(
        web: () => 'web-sync',
        desktop: () => 'desktop-sync',
      );
      
      if (PlatformUtils.isWeb) {
        expect(result, 'web-sync');
      } else {
        expect(result, 'desktop-sync');
      }
    });

    test('should handle different return types', () {
      final intResult = PlatformUtils.platformSpecificSync(
        web: () => 1,
        desktop: () => 2,
      );
      expect(intResult, isA<int>());

      final boolResult = PlatformUtils.platformSpecificSync(
        web: () => true,
        desktop: () => false,
      );
      expect(boolResult, isA<bool>());
    });
  });

  group('PlatformUtils.onWeb', () {
    test('should execute only on web', () async {
      int callCount = 0;
      final result = await PlatformUtils.onWeb(() async {
        callCount++;
        return 'web-only';
      });
      
      if (PlatformUtils.isWeb) {
        expect(result, 'web-only');
        expect(callCount, 1);
      } else {
        expect(result, null);
        expect(callCount, 0);
      }
    });
  });

  group('PlatformUtils.onDesktop', () {
    test('should execute only on desktop', () async {
      int callCount = 0;
      final result = await PlatformUtils.onDesktop(() async {
        callCount++;
        return 'desktop-only';
      });
      
      if (PlatformUtils.isDesktop) {
        expect(result, 'desktop-only');
        expect(callCount, 1);
      } else {
        expect(result, null);
        expect(callCount, 0);
      }
    });
  });
}
