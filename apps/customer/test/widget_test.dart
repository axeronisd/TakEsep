import 'package:flutter_test/flutter_test.dart';

import 'package:customer/main.dart';

void main() {
  testWidgets('AkJolCustomerApp renders', (WidgetTester tester) async {
    await tester.pumpWidget(const AkJolCustomerApp());
    expect(find.byType(AkJolCustomerApp), findsOneWidget);
  });
}
