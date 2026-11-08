import 'package:flutter_test/flutter_test.dart';
import 'package:raselna_chat/raselna_chat.dart';

import 'helpers.dart';

const _menu = MenuPrompt(
  options: [
    MenuOption(id: 'a', label: 'أ', index: 1),
    MenuOption(id: 'b', label: 'ب', index: 2),
  ],
);

void main() {
  test('load shows the first turn and the business config', () async {
    final t = FakeTransport(onStart: () => turn(_menu));
    final ctl = controllerFor(t);
    addTearDown(ctl.dispose);
    await ctl.load();
    expect(ctl.phase, ChatPhase.ready);
    expect(ctl.config!.botName, 'فرن الياسمين');
    expect(ctl.entries.single.text, 'أهلاً فيك 👋');
    expect(ctl.prompt, isA<MenuPrompt>());
  });

  test('an existing conversation is picked up instead of a new one', () async {
    final t = FakeTransport(onStart: () => turn(_menu))
      ..currentTurn = turn(const EndPrompt(), []);
    final ctl = controllerFor(t);
    addTearDown(ctl.dispose);
    await ctl.load();
    expect(t.starts, 0);
    expect(ctl.prompt, isA<EndPrompt>());
  });

  test(
    'offline replies queue, keep their key, persist, and send in order later',
    () async {
      final store = MemoryStore();
      final t = FakeTransport(
        onStart: () => turn(const InputPrompt()),
        onReply: (b) => turn(const InputPrompt(), ['تمام']),
      );
      final ctl = controllerFor(t, store: store);
      addTearDown(ctl.dispose);
      await ctl.load();

      t.offline = true;
      await ctl.sendText('أول');
      expect(ctl.entries.last.delivery, Delivery.queued);
      expect(ctl.isOffline, isTrue);
      expect(ctl.queuedCount, 1);
      expect(await store.read('queue'), contains('أول'));

      t.offline = false;
      await ctl.flushQueue();
      expect(t.idempotencyKeys, hasLength(2));
      expect(
        t.idempotencyKeys[0],
        t.idempotencyKeys[1],
        reason: 'a retry must reuse the key',
      );
      expect((t.replies.single as TextReply).text, 'أول');
      expect(ctl.queuedCount, 0);
      expect(await store.read('queue'), isNull);
      expect(
        ctl.entries.where((e) => e.side == ChatSide.customer).single.delivery,
        Delivery.sent,
      );
      expect(ctl.entries.last.text, 'تمام');
    },
  );

  test('a queue saved by a killed app is restored and sent on load', () async {
    final store = MemoryStore();
    final t = FakeTransport(onStart: () => turn(const InputPrompt()));
    final first = controllerFor(t, store: store);
    await first.load();
    t.offline = true;
    await first.sendText('0991234567');
    first.dispose();

    t.offline = false;
    t.currentTurn = turn(const InputPrompt(), []);
    final second = controllerFor(t, store: store);
    addTearDown(second.dispose);
    await second.load();
    // load() sends the restored queue on its own.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect((t.replies.single as TextReply).text, '0991234567');
    expect(second.queuedCount, 0);
  });

  test(
    'a rejected reply fails without retrying; a 410 ends the conversation',
    () async {
      final t = FakeTransport(onStart: () => turn(_menu));
      final ctl = controllerFor(t);
      addTearDown(ctl.dispose);
      await ctl.load();

      t.failWith = const RaselnaException('option_expired', status: 422);
      await ctl.choose(_menu.options.first);
      expect(ctl.entries.last.delivery, Delivery.failed);
      expect(ctl.canRetry(ctl.entries.last.key), isFalse);

      t.failWith = const RaselnaException('session_ended', status: 410);
      await ctl.choose(_menu.options.last);
      expect(ctl.prompt, isA<EndPrompt>());
      expect(ctl.queuedCount, 0);
    },
  );

  test('a 5xx keeps the reply for a manual retry with the same key', () async {
    final t = FakeTransport(onStart: () => turn(_menu));
    final ctl = controllerFor(t);
    addTearDown(ctl.dispose);
    await ctl.load();

    t.failWith = const RaselnaException('server_error', status: 503);
    await ctl.choose(_menu.options.first);
    final key = ctl.entries.last.key;
    expect(ctl.canRetry(key), isTrue);

    t.failWith = null;
    await ctl.retry(key);
    expect(t.idempotencyKeys.toSet(), hasLength(1));
    expect(ctl.entries.firstWhere((e) => e.key == key).delivery, Delivery.sent);
  });

  test(
    'the simulated handoff completes the catalog step and continues',
    () async {
      final ctl = controllerFor(
        MockTransport(latency: Duration.zero, typing: false),
      );
      addTearDown(ctl.dispose);
      await ctl.load();
      await ctl.choose((ctl.prompt as MenuPrompt).options.first);
      expect(ctl.prompt, isA<HandoffPrompt>());
      await ctl.openHandoff();
      expect(ctl.prompt, isA<InputPrompt>());
      expect((ctl.prompt as InputPrompt).inputKind, InputKind.phone);
      expect(ctl.entries.any((e) => e.card?.status == '45,000 ل.س'), isTrue);
    },
  );

  group('MockTransport plays a whole conversation', () {
    test(
      'bakery: order, phone (with a wrong try), delivery, confirmation',
      () async {
        final ctl = controllerFor(
          MockTransport(latency: Duration.zero, typing: false),
        );
        addTearDown(ctl.dispose);
        await ctl.load();
        await ctl.sendText('1'); // typing the option number works too
        await ctl.openHandoff();
        await ctl.sendText('123');
        expect(ctl.entries.last.text, contains('الرقم مو صحيح'));
        await ctl.sendText('٠٩٩١٢٣٤٥٦٧');
        await ctl.choose((ctl.prompt as MenuPrompt).options.first);
        expect(ctl.prompt, isA<EndPrompt>());
        expect(ctl.entries.last.card!.title, 'طلب رقم 1042');
      },
    );

    test('bakery: tracking an order', () async {
      final ctl = controllerFor(
        MockTransport(latency: Duration.zero, typing: false),
      );
      addTearDown(ctl.dispose);
      await ctl.load();
      await ctl.choose((ctl.prompt as MenuPrompt).options[2]);
      expect((ctl.prompt as InputPrompt).inputKind, InputKind.number);
      await ctl.sendText('1042');
      expect(ctl.entries.last.card!.status, 'بالطريق إليك');
    });

    test(
      'clinic: list menu, service, day, time, name, phone, booked',
      () async {
        final ctl = controllerFor(
          MockTransport(
            scenario: MockScenario.clinic,
            latency: Duration.zero,
            typing: false,
          ),
        );
        addTearDown(ctl.dispose);
        await ctl.load();
        final menu = ctl.prompt as MenuPrompt;
        expect(menu.display, MenuDisplay.list);
        await ctl.choose(menu.options.first);
        await ctl.choose((ctl.prompt as MenuPrompt).options.first);
        final days = ctl.prompt as SlotsPrompt;
        await ctl.chooseSlot(days.groups.single.options[3]);
        final times = ctl.prompt as SlotsPrompt;
        expect(times.groups, hasLength(3));
        await ctl.chooseSlot(times.groups.first.options[2]);
        await ctl.sendText('سلمى');
        await ctl.sendText('0991234567');
        expect(ctl.prompt, isA<EndPrompt>());
        expect(
          ctl.entries[ctl.entries.length - 2].card!.title,
          'الثلاثاء 18 · 10:30',
        );
      },
    );

    test(
      'clinic: talking to staff pauses with a number, and continues',
      () async {
        final ctl = controllerFor(
          MockTransport(
            scenario: MockScenario.clinic,
            latency: Duration.zero,
            typing: false,
          ),
        );
        addTearDown(ctl.dispose);
        await ctl.load();
        await ctl.choose((ctl.prompt as MenuPrompt).options[3]);
        expect((ctl.prompt as PausedPrompt).code, '48271-95306');
        await ctl.continueConversation();
        expect(ctl.prompt, isA<MenuPrompt>());
      },
    );
  });

  test('typing reveals messages one by one', () async {
    final t = FakeTransport(
      onStart:
          () => const ChatTurn(
            messages: [
              TextMessage(id: '1', text: 'أول', typingMs: 50),
              TextMessage(id: '2', text: 'تاني', typingMs: 50),
            ],
            prompt: EndPrompt(),
          ),
    );
    final ctl = RaselnaChatController(transport: t);
    addTearDown(ctl.dispose);
    final seen = <bool>[];
    ctl.addListener(() => seen.add(ctl.isTyping));
    await ctl.load();
    expect(seen, contains(true));
    expect(ctl.isTyping, isFalse);
    expect(ctl.entries.map((e) => e.text), ['أول', 'تاني']);
  });

  group('RaselnaChat.init', () {
    test('refuses secret-looking keys without echoing them', () async {
      await expectLater(
        RaselnaChat.init(accessKey: 'rsk_live_supersecret'),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.invalidValue,
            'value',
            '<redacted>',
          ),
        ),
      );
      await expectLater(
        RaselnaChat.init(accessKey: 'hello'),
        throwsArgumentError,
      );
    });

    test('refuses a plain-http base URL', () async {
      await expectLater(
        RaselnaChat.init(
          accessKey: 'rpk_test_x',
          baseUrl: Uri.parse('http://api.example.com'),
        ),
        throwsArgumentError,
      );
    });

    test('accepts a publishable key or a custom transport', () async {
      await RaselnaChat.init(accessKey: 'rpk_test_x', store: MemoryStore());
      expect(RaselnaChat.isInitialized, isTrue);
      await RaselnaChat.init(
        accessKey: '',
        transport: MockTransport(),
        store: MemoryStore(),
      );
      expect(RaselnaChat.controller.transport, isA<MockTransport>());
    });
  });
}
