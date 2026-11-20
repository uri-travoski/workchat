import 'package:flutter_test/flutter_test.dart';
import 'package:workchat/main.dart';

void main() {
  testWidgets('WorkChat app boots smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const WorkChatApp());
    expect(find.byType(WorkChatApp), findsOneWidget);
  });
}
