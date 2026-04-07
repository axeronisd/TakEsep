import 'package:flutter_test/flutter_test.dart';

import 'package:courier/main.dart';

void main() {
  testWidgets('AkJolCourierApp renders', (WidgetTester tester) async {
    await tester.pumpWidget(const AkJolCourierApp());
    expect(find.byType(AkJolCourierApp), findsOneWidget);
  });
}
