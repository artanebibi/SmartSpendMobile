import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/features/auth/providers/auth_provider.dart';
import 'package:smartspend/main.dart';

void main() {
  testWidgets('app smoke test — renders without crashing',
      (WidgetTester tester) async {
    final auth = AuthProvider();
    await tester.pumpWidget(SmartSpendApp(authProvider: auth));
    await tester.pump();
  });
}
