import 'dart:ui' show Color;

import 'models.dart';
import 'transport.dart';

/// Which demo business the [MockTransport] plays.
enum MockScenario {
  /// A bakery: menu, catalog (continues in the browser), phone, delivery,
  /// order confirmation, order tracking.
  bakery,

  /// A dental clinic: long menu (sheet), service, day and time slots, name,
  /// phone, booking confirmation, a paused hand-over to staff.
  clinic,
}

/// Plays a full scripted conversation on the device, with no network. Use it
/// to try the UI, in previews and in tests. Everything a real server would
/// decide (validation, next step) is decided here, in the same shapes.
class MockTransport extends RaselnaTransport {
  MockTransport({
    this.scenario = MockScenario.bakery,
    this.latency = const Duration(milliseconds: 350),
    this.typing = true,
  });

  final MockScenario scenario;

  /// Simulated network round trip.
  final Duration latency;

  /// Whether bot messages ask for a "typing…" pause.
  final bool typing;

  String? _state;
  String _day = '';
  String _time = '';
  bool _offline = false;

  /// Simulate losing the network: calls throw [RaselnaNetworkException].
  void setOffline(bool offline) => _offline = offline;

  Future<void> _wait() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    if (_offline) throw const RaselnaNetworkException('mock offline');
  }

  @override
  Future<ChatConfig> config() async {
    await _wait();
    return switch (scenario) {
      MockScenario.bakery => const ChatConfig(
        botName: 'فرن الياسمين',
        statusText: 'خبز وحلويات طازة كل يوم',
        palette: TenantPalette(primary: Color(0xFFB4441A)),
      ),
      MockScenario.clinic => const ChatConfig(
        botName: 'عيادة د. سلمى',
        statusText: 'طب الأسنان والتقويم',
        palette: TenantPalette(primary: Color(0xFF0F766E)),
      ),
    };
  }

  @override
  Future<ChatTurn?> current() async {
    final s = _state;
    if (s == null) return null;
    await _wait();
    if (s == 'b.catalog.done') return _step('b.cart');
    return _step(s, redisplay: true);
  }

  @override
  Future<ChatTurn> start() async {
    await _wait();
    _day = '';
    _time = '';
    return _step(scenario == MockScenario.bakery ? 'b.welcome' : 'c.welcome');
  }

  @override
  Future<ChatTurn> continueConversation() async {
    await _wait();
    return _step(scenario == MockScenario.bakery ? 'b.welcome' : 'c.menu');
  }

  @override
  Future<HandoffLink> handoffLink() async {
    await _wait();
    if (_state == 'b.catalog') _state = 'b.catalog.done';
    return HandoffLink(
      url: Uri.parse('https://demo.raselna.com/#h=mock'),
      simulated: true,
    );
  }

  @override
  Future<void> reset() async {
    _state = null;
  }

  @override
  Future<ChatTurn> reply(
    ReplyBody body, {
    required String idempotencyKey,
  }) async {
    await _wait();
    final s = _state ?? '';
    final option = switch (body) {
      OptionReply(:final optionId) => optionId,
      TextReply(:final text) => _optionFromNumber(s, text),
    };
    final text = body is TextReply ? body.text.trim() : '';

    switch (s) {
      case 'b.welcome':
      case 'b.hours':
        return switch (option) {
          'b.order' => _step('b.catalog'),
          'b.hours' => _step('b.hours'),
          'b.track' => _step('b.track'),
          'b.back' => _step('b.welcome', redisplay: true),
          _ => _retry(s),
        };
      case 'b.cart':
        if (!_validPhone(text)) {
          return _step(
            'b.cart',
            error: 'الرقم مو صحيح. اكتبه بالشكل 09xxxxxxxx.',
          );
        }
        return _step('b.delivery');
      case 'b.delivery':
        return option == 'b.home' || option == 'b.pickup'
            ? _step('b.done', extra: option)
            : _retry(s);
      case 'b.track':
        final n = _digits(text);
        if (n.isEmpty || n.length > 8) {
          return _step('b.track', error: 'رقم الطلب أرقام بس، متل 1042.');
        }
        return _step('b.tracked', extra: n);

      case 'c.welcome':
      case 'c.menu':
      case 'c.info':
        return switch (option) {
          'c.book' => _step('c.service'),
          'c.prices' => _step('c.prices'),
          'c.where' => _step('c.where'),
          'c.human' => _step('c.human'),
          'c.back' => _step('c.menu'),
          _ => _retry(s),
        };
      case 'c.service':
        return option != null && option.startsWith('c.s.')
            ? _step('c.days')
            : _retry(s);
      case 'c.days':
        if (option == 'c.more') return _step('c.days', extra: 'more');
        final day =
            _days.where((d) => d.id == option).firstOrNull ??
            _moreDays.where((d) => d.id == option).firstOrNull;
        if (day == null) return _retry(s);
        _day = day.label;
        return _step('c.times');
      case 'c.times':
        if (option == 'c.otherday') return _step('c.days');
        final time =
            _times
                .expand((g) => g.options)
                .where((t) => t.id == option)
                .firstOrNull;
        if (time == null) return _retry(s);
        _time = time.label;
        return _step('c.name');
      case 'c.name':
        if (text.length < 2) {
          return _step('c.name', error: 'اكتب اسمك لو سمحت.');
        }
        return _step('c.phone');
      case 'c.phone':
        if (!_validPhone(text)) {
          return _step(
            'c.phone',
            error: 'الرقم مو صحيح. اكتبه بالشكل 09xxxxxxxx.',
          );
        }
        return _step('c.done');
      default:
        return start();
    }
  }

  ChatTurn _retry(String state) =>
      _step(state, error: 'اختار من الخيارات لو سمحت.', redisplay: true);

  // --- The script ---------------------------------------------------------

  int _seq = 0;

  TextMessage _t(String text, {int typingMs = 700, StatusCard? card}) =>
      TextMessage(
        id: 'm${++_seq}',
        text: text,
        typingMs: typing ? typingMs : 0,
        card: card,
      );

  ChatTurn _step(
    String state, {
    String? error,
    String? extra,
    bool redisplay = false,
  }) {
    _state = state;
    final messages = <ChatMessage>[if (error != null) _t(error, typingMs: 300)];
    final say = !redisplay && error == null;
    void add(TextMessage m) {
      if (say) messages.add(m);
    }

    final Prompt prompt;
    switch (state) {
      case 'b.welcome':
        add(_t('أهلاً فيك بفرن الياسمين 👋', typingMs: 500));
        add(_t('كيف فينا نساعدك اليوم؟'));
        prompt = const MenuPrompt(
          options: [
            MenuOption(id: 'b.order', label: 'اطلب خبز وحلويات 🥐', index: 1),
            MenuOption(id: 'b.hours', label: 'أوقات الدوام والموقع', index: 2),
            MenuOption(id: 'b.track', label: 'وين وصل طلبي؟', index: 3),
          ],
        );
      case 'b.hours':
        add(
          _t(
            'فاتحين كل يوم من 6 الصبح لـ 10 المسا ☀️\n'
            '📍 المزة، جانب الحديقة. التوصيل لكل دمشق.',
          ),
        );
        prompt = const MenuPrompt(
          options: [
            MenuOption(id: 'b.order', label: 'اطلب هلأ', index: 1),
            MenuOption(id: 'b.back', label: 'رجوع', index: 2),
          ],
        );
      case 'b.catalog':
        add(_t('تكرم عينك! هي قائمة اليوم، كلها طازة من الفرن.'));
        prompt = const HandoffPrompt(
          kind: 'product_list',
          reason: HandoffReason.catalog,
          count: 12,
        );
      case 'b.cart':
        if (say) {
          messages.add(
            _t(
              'وصلتنا سلتك 🛒',
              card: const StatusCard(
                title: 'كرواسون زعتر ×2 · كعك بسمسم ×1',
                status: '45,000 ل.س',
              ),
            ),
          );
          messages.add(_t('شو رقم موبايلك لنأكد معك الطلب؟'));
        }
        prompt = const InputPrompt(
          inputKind: InputKind.phone,
          placeholder: '09xxxxxxxx',
          progress: StepProgress(1, 2),
        );
      case 'b.delivery':
        add(_t('توصيل للبيت ولا بتمرق تاخدو من المحل؟'));
        prompt = const MenuPrompt(
          options: [
            MenuOption(id: 'b.home', label: 'توصيل للبيت 🛵', index: 1),
            MenuOption(id: 'b.pickup', label: 'باخدو من المحل', index: 2),
          ],
        );
      case 'b.done':
        messages.add(_t('تمام، وصل طلبك! 🎉'));
        messages.add(
          _t(
            extra == 'b.home'
                ? 'رح يوصلك خلال ساعة تقريباً. صحتين وعافية!'
                : 'رح يكون جاهز بعد نص ساعة. منستناك!',
            card: const StatusCard(
              title: 'طلب رقم 1042',
              status: 'قيد التحضير',
              tone: StatusTone.success,
            ),
          ),
        );
        prompt = const EndPrompt();
      case 'b.track':
        add(_t('اكتب رقم الطلب يلي وصلك برسالة التأكيد:'));
        prompt = const InputPrompt(
          inputKind: InputKind.number,
          placeholder: 'مثلاً 1042',
        );
      case 'b.tracked':
        messages.add(
          _t(
            'لقيناه 👇',
            card: StatusCard(
              title: 'طلب رقم $extra',
              status: 'بالطريق إليك',
              tone: StatusTone.warning,
            ),
          ),
        );
        prompt = const EndPrompt();

      case 'c.welcome':
        add(_t('أهلاً فيك بعيادة د. سلمى لطب الأسنان 🦷', typingMs: 500));
        add(_t('كيف فينا نخدمك؟'));
        prompt = _clinicMenu;
      case 'c.menu':
        add(_t('أكيد، شو بتحب نعمل؟'));
        prompt = _clinicMenu;
      case 'c.prices':
        add(
          _t(
            'فحص وتنظيف: 75,000 ل.س\nحشوة تجميلية: من 150,000 ل.س\n'
            'استشارة تقويم: مجانية',
          ),
        );
        _state = 'c.info';
        prompt = _infoMenu;
      case 'c.where':
        add(
          _t(
            '📍 أبو رمانة، بناية النخيل، طابق تاني.\n'
            'الدوام من السبت للخميس، 9 الصبح لـ 7 المسا.',
          ),
        );
        _state = 'c.info';
        prompt = _infoMenu;
      case 'c.human':
        add(_t('السكرتيرة رح تتواصل معك بأقرب وقت 🙏'));
        prompt = const PausedPrompt(code: '48271-95306');
      case 'c.service':
        add(_t('شو نوع الزيارة؟'));
        prompt = const MenuPrompt(
          options: [
            MenuOption(id: 'c.s.check', label: 'فحص وتنظيف', index: 1),
            MenuOption(id: 'c.s.fill', label: 'حشوة', index: 2),
            MenuOption(id: 'c.s.ortho', label: 'استشارة تقويم', index: 3),
          ],
        );
      case 'c.days':
        add(_t('اختار اليوم يلي بيناسبك:'));
        prompt = SlotsPrompt(
          title: 'الأيام المتاحة',
          groups: [SlotGroup(options: extra == 'more' ? _moreDays : _days)],
          actions: [
            if (extra != 'more')
              const SlotOption(id: 'c.more', label: 'أيام تانية'),
          ],
        );
      case 'c.times':
        add(_t('يوم $_day، اختار الوقت:'));
        prompt = const SlotsPrompt(
          title: 'الأوقات المتاحة',
          groups: _times,
          actions: [SlotOption(id: 'c.otherday', label: 'يوم تاني')],
        );
      case 'c.name':
        add(_t('حلو! شو الاسم الكريم؟'));
        prompt = const InputPrompt(
          placeholder: 'الاسم الكامل',
          progress: StepProgress(1, 2),
        );
      case 'c.phone':
        add(_t('ورقم موبايلك لنذكّرك بالموعد؟'));
        prompt = const InputPrompt(
          inputKind: InputKind.phone,
          placeholder: '09xxxxxxxx',
          progress: StepProgress(2, 2),
        );
      case 'c.done':
        messages.add(
          _t(
            'تمّ الحجز ✅',
            card: StatusCard(
              title: '$_day · $_time',
              status: 'موعد مؤكد',
              tone: StatusTone.success,
            ),
          ),
        );
        messages.add(
          _t('رح نذكّرك قبلها بيوم. إذا بدك تغيّر الموعد احكينا هون.'),
        );
        prompt = const EndPrompt();
      default:
        prompt = const NonePrompt();
    }
    return ChatTurn(messages: messages, prompt: prompt);
  }

  static const _clinicMenu = MenuPrompt(
    display: MenuDisplay.list,
    listButtonText: 'عرض الخيارات',
    options: [
      MenuOption(id: 'c.book', label: 'حجز موعد', index: 1),
      MenuOption(id: 'c.prices', label: 'أسعار الخدمات', index: 2),
      MenuOption(id: 'c.where', label: 'موقع العيادة والدوام', index: 3),
      MenuOption(id: 'c.human', label: 'بدي احكي مع السكرتيرة', index: 4),
    ],
  );

  static const _infoMenu = MenuPrompt(
    options: [
      MenuOption(id: 'c.book', label: 'احجز موعد', index: 1),
      MenuOption(id: 'c.back', label: 'رجوع', index: 2),
    ],
  );

  static const _days = [
    SlotOption(id: 'c.d.1', label: 'السبت 15'),
    SlotOption(id: 'c.d.2', label: 'الأحد 16'),
    SlotOption(id: 'c.d.3', label: 'الاثنين 17'),
    SlotOption(id: 'c.d.4', label: 'الثلاثاء 18'),
    SlotOption(id: 'c.d.5', label: 'الأربعاء 19'),
  ];

  static const _moreDays = [
    SlotOption(id: 'c.d.6', label: 'الخميس 20'),
    SlotOption(id: 'c.d.7', label: 'السبت 22'),
    SlotOption(id: 'c.d.8', label: 'الأحد 23'),
  ];

  static const _times = [
    SlotGroup(
      label: 'الصبح',
      options: [
        SlotOption(id: 'c.t.1', label: '9:00'),
        SlotOption(id: 'c.t.2', label: '9:30'),
        SlotOption(id: 'c.t.3', label: '10:30'),
        SlotOption(id: 'c.t.4', label: '11:00'),
      ],
    ),
    SlotGroup(
      label: 'الضهر',
      options: [
        SlotOption(id: 'c.t.5', label: '1:00'),
        SlotOption(id: 'c.t.6', label: '2:30'),
      ],
    ),
    SlotGroup(
      label: 'المسا',
      options: [
        SlotOption(id: 'c.t.7', label: '5:00'),
        SlotOption(id: 'c.t.8', label: '6:30'),
      ],
    ),
  ];

  // --- Helpers --------------------------------------------------------------

  /// "2" typed on a menu picks option 2, like on the web chat.
  String? _optionFromNumber(String state, String text) {
    final n = int.tryParse(_digits(text));
    if (n == null) return null;
    final prompt = _step(state, redisplay: true).prompt;
    _state = state;
    if (prompt is MenuPrompt) {
      return prompt.options.where((o) => o.index == n).firstOrNull?.id;
    }
    return null;
  }

  static bool _validPhone(String text) {
    final d = _digits(text);
    return d.length >= 9 && d.length <= 15;
  }

  /// Digits only, Arabic-Indic and Persian digits mapped to ASCII.
  static String _digits(String text) {
    final b = StringBuffer();
    for (final r in text.runes) {
      if (r >= 0x30 && r <= 0x39) {
        b.writeCharCode(r);
      } else if (r >= 0x660 && r <= 0x669) {
        b.writeCharCode(r - 0x660 + 0x30);
      } else if (r >= 0x6F0 && r <= 0x6F9) {
        b.writeCharCode(r - 0x6F0 + 0x30);
      }
    }
    return b.toString();
  }
}
