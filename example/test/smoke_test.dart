import 'package:flutter_test/flutter_test.dart';
import 'package:raselna_chat/raselna_chat.dart';
import 'package:raselna_chat_example/main.dart';

void main() {
  testWidgets('the demo opens the mock chat', (tester) async {
    await RaselnaChat.init(
      accessKey: 'rpk_test_demo',
      transport: MockTransport(latency: Duration.zero, typing: false),
      store: MemoryStore(),
    );
    await tester.pumpWidget(const DemoApp());
    await tester.pumpAndSettle();
    expect(find.text('فرن الياسمين', skipOffstage: false), findsOneWidget);
  });
}
