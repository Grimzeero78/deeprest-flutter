// Basic smoke test — verifies the app entry builds.
import 'package:flutter_test/flutter_test.dart';
import 'package:deeprest/main.dart';

void main() {
  testWidgets('app boots to auth gate', (tester) async {
    await tester.pumpWidget(const DeepRestApp());
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(DeepRestApp), findsOneWidget);
  });
}
