import 'package:flutter_test/flutter_test.dart';

import 'package:fitflow/main.dart';

void main() {
  testWidgets('app starts on Momentum splash', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('MOMENTUM'), findsOneWidget);
  });
}
