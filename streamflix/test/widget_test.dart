import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streamflix/main.dart';

void main() {
  testWidgets('Smoke test app launch', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: StreamFlixApp(),
      ),
    );
  });
}
