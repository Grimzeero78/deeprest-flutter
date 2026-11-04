// Basic smoke test — verifies the app entry builds.
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:deeprest/main.dart';
import 'package:deeprest/core/permissions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app boots to auth gate', (tester) async {
    await tester.pumpWidget(const DeepRestApp());
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(DeepRestApp), findsOneWidget);
  });

  test('notification permission is checked after the first request', () async {
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel('deeprest/device');
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return false;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    expect(await DevicePermissions.requestNotificationsOnce(), isFalse);
    expect(await DevicePermissions.requestNotificationsOnce(), isFalse);
    expect(calls, ['requestNotifications', 'hasNotificationPermission']);
  });
}
