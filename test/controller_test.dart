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
    'rich steps stay on screen, disabled, while an action is on its way',
    () async {
      final ctl = controllerFor(
        MockTransport(latency: Duration.zero, typing: false),
      );
      addTearDown(ctl.dispose);
      await ctl.load();
      await ctl.choose((ctl.prompt as MenuPrompt).options.first);
      final catalog = ctl.prompt as ProductListPrompt;
      expect(ctl.richPrompt, same(catalog));
      final shown = <bool>[];
      ctl.addListener(
        () => shown.add(ctl.isBusy && ctl.richPrompt is ProductListPrompt),
      );
      await ctl.act(
        const ActionReply('add', product: 'p.kaak', qty: 2),
        echo: '➕ 2 × كعك',
      );
      expect(shown, contains(true), reason: 'the catalogue stays while busy');
      expect((ctl.prompt as ProductListPrompt).cartCount, 1);
    },
  );

  test('an offline action is queued and replayed with the same key', () async {
    final store = MemoryStore();
    final t = FakeTransport(
      onStart: () => turn(const CartPrompt(canCheckout: true)),
    );
    final ctl = controllerFor(t, store: store);
    addTearDown(ctl.dispose);
    await ctl.load();
    t.offline = true;
    await ctl.act(
      const ActionReply('set_qty', line: 'l1', qty: 3),
      echo: '✏️ كعك × 3',
    );
    expect(await store.read('queue'), contains('set_qty'));
    t.offline = false;
    await ctl.flushQueue();
    expect(t.idempotencyKeys.toSet(), hasLength(1));
    final sent = t.replies.single as ActionReply;
    expect(sent.type, 'set_qty');
    expect(sent.qty, 3);
  });

  group('MockTransport plays a whole conversation', () {
    test(
      'bakery: catalogue (options, quarter kilos), cart, checkout with errors, confirmation',
      () async {
        final ctl = controllerFor(
          MockTransport(latency: Duration.zero, typing: false),
        );
        addTearDown(ctl.dispose);
        await ctl.load();
        await ctl.sendText('1'); // typing the option number works too
        final catalog = ctl.prompt as ProductListPrompt;
        expect(catalog.products.any((p) => !p.available), isTrue);

        // A required option missing: the server says so, nothing is added.
        await ctl.act(
          const ActionReply('add', product: 'p.croissant', qty: 2),
          echo: 'x',
        );
        expect((ctl.prompt as ProductListPrompt).cartCount, 0);
        expect(ctl.entries.last.text, contains('الحشوة'));

        await ctl.act(
          const ActionReply(
            'add',
            product: 'p.croissant',
            qty: 2,
            options: ['o.cheese'],
          ),
          echo: 'x',
        );
        await ctl.act(
          const ActionReply('add', product: 'p.maamoul', qty: 0.75),
          echo: 'x',
        );
        final after = ctl.prompt as ProductListPrompt;
        expect(after.cartCount, 2);
        expect(after.cartTotal, '104,000 ل.س');

        await ctl.act(const ActionReply('done'), echo: 'x');
        final cart = ctl.prompt as CartPrompt;
        expect(cart.lines.first.options, 'زعتر وجبنة');
        expect(cart.lines.last.qty, 0.75);
        await ctl.act(
          ActionReply('remove', line: cart.lines.last.id),
          echo: 'x',
        );
        expect((ctl.prompt as CartPrompt).subtotal, '14,000 ل.س');

        await ctl.act(const ActionReply('confirm'), echo: 'x');
        final form = ctl.prompt as FormPrompt;
        expect(
          form.fields.map((f) => f.name),
          containsAll(['fulfillment', 'zone', 'address', 'name', 'phone']),
        );

        await ctl.act(
          const ActionReply(
            'submit',
            values: {'fulfillment': 'delivery', 'name': 'س', 'phone': '12'},
          ),
          echo: 'x',
        );
        final again = ctl.prompt as FormPrompt;
        expect(again.hasErrors, isTrue);
        expect(
          again.fields.firstWhere((f) => f.name == 'phone').error,
          isNotNull,
        );
        expect(
          again.fields.firstWhere((f) => f.name == 'zone').error,
          isNotNull,
        );

        await ctl.act(
          const ActionReply(
            'submit',
            values: {
              'fulfillment': 'delivery',
              'zone': 'z.mazzeh',
              'address': 'المزة، شارع الجلاء، بناية 4',
              'time': 'asap',
              'name': 'سلمى',
              'phone': '0991234567',
            },
          ),
          echo: 'x',
        );
        expect(ctl.prompt, isA<EndPrompt>());
        expect(ctl.entries.last.card!.title, 'طلب رقم 1042 · 19,000 ل.س');
      },
    );

    test('store: range, pick results, more, select', () async {
      final ctl = controllerFor(
        MockTransport(
          scenario: MockScenario.store,
          latency: Duration.zero,
          typing: false,
        ),
      );
      addTearDown(ctl.dispose);
      await ctl.load();
      await ctl.choose((ctl.prompt as MenuPrompt).options.first);
      expect((ctl.prompt as FormPrompt).isRange, isTrue);
      await ctl.act(
        const ActionReply('submit', values: {'min': '100', 'max': '400'}),
        echo: 'x',
      );
      final first = ctl.prompt as ProductListPrompt;
      expect(first.isPick, isTrue);
      expect(first.hasMore, isTrue);
      await ctl.act(const ActionReply('more'), echo: 'x');
      final second = ctl.prompt as ProductListPrompt;
      expect(second.hasMore, isFalse);
      await ctl.act(
        ActionReply('select', product: second.products.first.id),
        echo: 'x',
      );
      expect(ctl.prompt, isA<EndPrompt>());
      expect(
        ctl.entries.any((e) => e.card?.status == 'محجوز إلك 24 ساعة'),
        isTrue,
      );
    });

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
