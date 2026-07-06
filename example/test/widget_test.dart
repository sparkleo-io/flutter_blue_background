// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/services.dart';
import 'package:flutter_blue_background_example/app/ble_example_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('flutter_blue_background');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'isServiceRunning':
          return false;
        case 'startService':
        case 'stopService':
          return true;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('Renders start/stop controls', (WidgetTester tester) async {
    await tester.pumpWidget(const BleExampleApp());
    await tester.pumpAndSettle();

    expect(find.text('Start service'), findsOneWidget);
    expect(find.text('Stop service'), findsOneWidget);
    expect(find.text('Service: STOPPED'), findsOneWidget);
  });
}
