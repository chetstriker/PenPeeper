import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penpeeper/utils/clipboard_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (MethodCall methodCall) async {
      if (methodCall.method == 'Clipboard.setData') {
        return null;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('ClipboardHelper.copyQuiet', () {
    test('should copy text without feedback', () async {
      await ClipboardHelper.copyQuiet('test text');
      // No exception means success
    });

    test('should handle empty string', () async {
      await ClipboardHelper.copyQuiet('');
      // No exception means success
    });

    test('should handle special characters', () async {
      await ClipboardHelper.copyQuiet('192.168.1.1\n\t"quotes"');
      // No exception means success
    });
  });

  group('ClipboardHelper.copy', () {
    testWidgets('should copy without context', (WidgetTester tester) async {
      await ClipboardHelper.copy('test data');
      // No exception means success
    });

    testWidgets('should copy with context but no message', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                ClipboardHelper.copy('test', context: context);
                return Container();
              },
            ),
          ),
        ),
      );
      await tester.pump();
    });

    testWidgets('should show success message when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                ClipboardHelper.copy(
                  'test',
                  successMessage: 'Copied!',
                  context: context,
                );
                return Container();
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(Duration(milliseconds: 100));
      
      expect(find.text('Copied!'), findsOneWidget);
    });
  });
}
