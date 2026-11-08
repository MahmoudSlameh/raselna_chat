import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raselna_chat/raselna_chat.dart';

import 'helpers.dart';

const _three = MenuPrompt(
  options: [
    MenuOption(id: 'o1', label: 'اطلب خبز', index: 1),
    MenuOption(id: 'o2', label: 'أوقات الدوام', index: 2),
    MenuOption(id: 'o3', label: 'تتبّع طلب', index: 3),
  ],
);

void main() {
  testWidgets('header, bot bubble and right-to-left layout', (tester) async {
    await pumpChat(tester, FakeTransport(onStart: () => turn(_three)));
    expect(find.text('فرن الياسمين'), findsOneWidget);
    expect(find.text('متصل الآن'), findsOneWidget);
    expect(find.text('أهلاً فيك 👋'), findsOneWidget);
    expect(find.text('مدعوم من راسلنا'), findsOneWidget);
    final dir = tester.widget<Directionality>(
      find
          .ancestor(
            of: find.text('أهلاً فيك 👋'),
            matching: find.byType(Directionality),
          )
          .first,
    );
    expect(dir.textDirection, TextDirection.rtl);
    // The bot bubble starts at the right edge in Arabic.
    final bubble = tester.getTopRight(find.text('أهلاً فيك 👋'));
    expect(
      bubble.dx,
      greaterThan(
        tester.view.physicalSize.width / tester.view.devicePixelRatio / 2,
      ),
    );
  });

  testWidgets('menu buttons: chips under the bubble send the option id', (
    tester,
  ) async {
    final t = FakeTransport(
      onStart: () => turn(_three),
      onReply: (_) => turn(const EndPrompt(), ['تمام']),
    );
    await pumpChat(tester, t);
    expect(find.text('اطلب خبز'), findsOneWidget);
    expect(find.text('تتبّع طلب'), findsOneWidget);

    await tester.tap(find.text('أوقات الدوام'));
    await tester.pumpAndSettle();
    expect((t.replies.single as OptionReply).optionId, 'o2');
    // The echo bubble shows the label; the old chips are gone.
    expect(find.text('أوقات الدوام'), findsOneWidget);
    expect(find.text('اطلب خبز'), findsNothing);
    expect(find.text('تمام'), findsOneWidget);
    expect(find.text('البدء من جديد'), findsOneWidget);
  });

  testWidgets('menu list: a sheet with numbered options', (tester) async {
    final t = FakeTransport(
      onStart:
          () => turn(
            const MenuPrompt(
              display: MenuDisplay.list,
              listButtonText: 'عرض الخيارات',
              options: [
                MenuOption(id: 'c1', label: 'حجز موعد', index: 1),
                MenuOption(id: 'c2', label: 'الأسعار', index: 2),
                MenuOption(id: 'c3', label: 'الموقع', index: 3),
                MenuOption(id: 'c4', label: 'السكرتيرة', index: 4),
              ],
            ),
          ),
    );
    await pumpChat(tester, t);
    expect(find.text('حجز موعد'), findsNothing);
    await tester.tap(find.text('عرض الخيارات'));
    await tester.pumpAndSettle();
    expect(find.text('4'), findsOneWidget);
    await tester.tap(find.text('الموقع'));
    await tester.pumpAndSettle();
    expect((t.replies.single as OptionReply).optionId, 'c3');
  });

  testWidgets('text input sends the typed answer', (tester) async {
    final t = FakeTransport(
      onStart: () => turn(const InputPrompt(placeholder: 'الاسم الكامل')),
    );
    await pumpChat(tester, t);
    expect(find.text('الاسم الكامل'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '  سلمى  ');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();
    expect((t.replies.single as TextReply).text, 'سلمى');
  });

  testWidgets('number input: rejects letters, normalizes Arabic digits', (
    tester,
  ) async {
    final t = FakeTransport(
      onStart: () => turn(const InputPrompt(inputKind: InputKind.number)),
    );
    await pumpChat(tester, t);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(
      field.keyboardType,
      const TextInputType.numberWithOptions(decimal: true),
    );

    await tester.enterText(find.byType(TextField), '12ب');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    expect(find.text('اكتب أرقام بس.'), findsOneWidget);
    expect(t.replies, isEmpty);

    await tester.enterText(find.byType(TextField), '١٠٤٢');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    expect((t.replies.single as TextReply).text, '1042');
  });

  testWidgets('phone input: phone keyboard, validation, step progress', (
    tester,
  ) async {
    final t = FakeTransport(
      onStart:
          () => turn(
            const InputPrompt(
              inputKind: InputKind.phone,
              progress: StepProgress(1, 2),
            ),
          ),
    );
    await pumpChat(tester, t);
    expect(
      tester.widget<TextField>(find.byType(TextField)).keyboardType,
      TextInputType.phone,
    );
    expect(find.text('الخطوة 1 من 2'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '12');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    expect(find.text('اكتب رقم موبايل صحيح.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '0991 234 567');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    expect((t.replies.single as TextReply).text, '0991 234 567');
  });

  testWidgets('email input: email keyboard and validation', (tester) async {
    final t = FakeTransport(
      onStart: () => turn(const InputPrompt(inputKind: InputKind.email)),
    );
    await pumpChat(tester, t);
    expect(
      tester.widget<TextField>(find.byType(TextField)).keyboardType,
      TextInputType.emailAddress,
    );
    await tester.enterText(find.byType(TextField), 'salma@clinic');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    expect(find.text('اكتب إيميل صحيح.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'salma@clinic.sy');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    expect((t.replies.single as TextReply).text, 'salma@clinic.sy');
  });

  testWidgets('slot picker: grouped chips and actions answer with option ids', (
    tester,
  ) async {
    final t = FakeTransport(
      onStart:
          () => turn(
            const SlotsPrompt(
              title: 'الأوقات المتاحة',
              groups: [
                SlotGroup(
                  label: 'الصبح',
                  options: [
                    SlotOption(id: 't1', label: '9:00'),
                    SlotOption(id: 't2', label: '10:30'),
                  ],
                ),
                SlotGroup(
                  label: 'المسا',
                  options: [SlotOption(id: 't3', label: '5:00')],
                ),
              ],
              actions: [SlotOption(id: 'other', label: 'يوم تاني')],
            ),
          ),
    );
    await pumpChat(tester, t);
    expect(find.text('الأوقات المتاحة'), findsOneWidget);
    expect(find.text('الصبح'), findsOneWidget);
    expect(find.text('المسا'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('10:30'));
    await tester.pumpAndSettle();
    expect((t.replies.single as OptionReply).optionId, 't2');
  });

  testWidgets('slot picker: empty state', (tester) async {
    await pumpChat(
      tester,
      FakeTransport(
        onStart:
            () => turn(
              const SlotsPrompt(
                title: 'الأيام',
                groups: [SlotGroup(options: [])],
              ),
            ),
      ),
    );
    expect(find.text('ما في مواعيد فاضية هلأ.'), findsOneWidget);
  });

  testWidgets('end: a big restart button starts again', (tester) async {
    final t = FakeTransport(onStart: () => turn(const EndPrompt()));
    await pumpChat(tester, t);
    await tester.tap(find.text('البدء من جديد'));
    await tester.pumpAndSettle();
    expect(t.starts, 2);
  });

  testWidgets('end without restart says the chat ended', (tester) async {
    await pumpChat(
      tester,
      FakeTransport(onStart: () => turn(const EndPrompt(showRestart: false))),
    );
    expect(find.text('انتهت المحادثة.'), findsOneWidget);
  });

  testWidgets('paused: the conversation number, copy, continue', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final t = FakeTransport(
      onStart: () => turn(const PausedPrompt(code: '48271-95306')),
    );
    await pumpChat(tester, t);
    expect(find.text('48271-95306'), findsOneWidget);
    expect(find.text('رقم المحادثة'), findsOneWidget);
    await tester.tap(find.text('نسخ'));
    await tester.pumpAndSettle();
    expect(find.text('انتسخ'), findsOneWidget);
    await tester.tap(find.text('رجعت؟ كمّل المحادثة'));
    await tester.pumpAndSettle();
    expect(t.continues, 1);
  });

  testWidgets('catalog: a "continue in browser" card opens the one-time link', (
    tester,
  ) async {
    final opened = <Uri>[];
    final t = FakeTransport(
      onStart:
          () => turn(
            Prompt.fromJson({
              'kind': 'product_list',
              'products': List.filled(12, {}),
            }),
          ),
    );
    await pumpChat(
      tester,
      t,
      openUrl: (u) async {
        opened.add(u);
        return true;
      },
    );
    expect(find.text('هالخطوة بتكمل بصفحة آمنة'), findsOneWidget);
    expect(find.text('12 منتج'), findsOneWidget);
    await tester.tap(find.text('متابعة بالمتصفح'));
    await tester.pumpAndSettle();
    expect(t.handoffs, 1);
    expect(opened.single.toString(), 'https://bakery.raselna.com/#h=abc');
    // Waiting for the customer to come back.
    expect(find.text('رجعت؟ كمّل'), findsOneWidget);

    // Back in the app: the next question is native again.
    t.currentTurn = turn(const InputPrompt(inputKind: InputKind.phone), [
      'وصلتنا سلتك',
    ]);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('وصلتنا سلتك'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('a secret input never shows a native field', (tester) async {
    await pumpChat(
      tester,
      FakeTransport(
        onStart:
            () => turn(
              Prompt.fromJson({'kind': 'input', 'input_type': 'password'}),
            ),
      ),
    );
    expect(find.byType(TextField), findsNothing);
    expect(
      find.text('هالمعلومة سرية، فمنطلبها بصفحة آمنة مو جوّا التطبيق.'),
      findsOneWidget,
    );
  });

  testWidgets('an unknown step falls back to the browser card', (tester) async {
    await pumpChat(
      tester,
      FakeTransport(onStart: () => turn(Prompt.fromJson({'kind': 'ar_tryon'}))),
    );
    expect(find.text('متابعة بالمتصفح'), findsOneWidget);
  });

  testWidgets('status card on a bot message', (tester) async {
    await pumpChat(
      tester,
      FakeTransport(
        onStart:
            () => const ChatTurn(
              messages: [
                TextMessage(
                  id: '1',
                  text: 'تمام، وصل طلبك! 🎉',
                  card: StatusCard(
                    title: 'طلب رقم 1042',
                    status: 'قيد التحضير',
                    tone: StatusTone.success,
                  ),
                ),
              ],
              prompt: EndPrompt(),
            ),
      ),
    );
    expect(find.text('طلب رقم 1042'), findsOneWidget);
    expect(find.text('قيد التحضير'), findsOneWidget);
  });

  testWidgets('typing indicator shows before a bot message', (tester) async {
    final t = FakeTransport(
      onStart:
          () => const ChatTurn(
            messages: [TextMessage(id: '1', text: 'لحظة…', typingMs: 800)],
            prompt: EndPrompt(),
          ),
    );
    final ctl = RaselnaChatController(transport: t);
    addTearDown(ctl.dispose);
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: RaselnaChatView(controller: ctl))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // The header says "typing…" and the message is not there yet.
    expect(find.text('يكتب…'), findsOneWidget);
    expect(find.text('لحظة…'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('يكتب…'), findsNothing);
    expect(find.text('لحظة…'), findsOneWidget);
  });

  testWidgets('offline: the reply waits with a banner, then goes', (
    tester,
  ) async {
    final t = FakeTransport(onStart: () => turn(_three));
    final ctl = await pumpChat(tester, t);
    t.offline = true;
    await tester.tap(find.text('اطلب خبز'));
    await tester.pumpAndSettle();
    expect(find.text('ما في إنترنت. رح نبعت رسائلك لما يرجع.'), findsOneWidget);
    expect(find.byIcon(Icons.schedule), findsOneWidget);
    t.offline = false;
    await ctl.flushQueue();
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.done_all), findsOneWidget);
  });

  testWidgets('English strings and left-to-right', (tester) async {
    await pumpChat(
      tester,
      FakeTransport(onStart: () => turn(const EndPrompt(), ['Hello'])),
      locale: 'en',
    );
    expect(find.text('Start over'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);
  });

  testWidgets('semantics: who said what, and a labelled send button', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpChat(
      tester,
      FakeTransport(onStart: () => turn(const InputPrompt())),
    );
    expect(
      find.bySemanticsLabel('فرن الياسمين قال: أهلاً فيك 👋'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('إرسال'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('large text (200%) lays out without overflow', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 720 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final ctl = controllerFor(
      FakeTransport(
        onStart:
            () => turn(_three, [
              'أهلاً فيك بفرن الياسمين، كيف فينا نساعدك اليوم؟',
            ]),
      ),
    );
    addTearDown(ctl.dispose);
    await tester.pumpWidget(
      MaterialApp(
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
        home: Scaffold(body: RaselnaChatView(controller: ctl)),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('أوقات الدوام'), findsOneWidget);
  });

  testWidgets('dark mode uses the dark surfaces', (tester) async {
    await pumpChat(
      tester,
      FakeTransport(onStart: () => turn(_three)),
      themeMode: ThemeMode.dark,
    );
    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(RaselnaChatView),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(material.color, const Color(0xFF0F1016));
  });
}
