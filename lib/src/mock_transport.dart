import 'dart:ui' show Color;

import 'models.dart';
import 'transport.dart';

/// Which demo business the [MockTransport] plays.
enum MockScenario {
  /// A bakery: menu, native catalogue (categories, options, quantities),
  /// cart, checkout form (delivery zone, address, time, phone), order
  /// confirmation; or tracking an order by number.
  bakery,

  /// A dental clinic: long menu (sheet), service, day and time slots, name,
  /// phone, booking confirmation, a paused hand-over to staff.
  clinic,

  /// A phone shop's product finder: question, price range, results with
  /// pictures and details, "I want this", show more, start over.
  store,
}

/// Plays a full scripted conversation on the device, with no network. Use it
/// to try the UI, in previews and in tests. Everything a real server would
/// decide (validation, next step) is decided here, in the same shapes.
class MockTransport extends RaselnaTransport {
  MockTransport({
    this.scenario = MockScenario.bakery,
    this.latency = const Duration(milliseconds: 350),
    this.typing = true,
    this.imageBase,
  });

  /// Where the demo product pictures live (e.g. the example app's web
  /// assets). Null = no pictures (letter tiles).
  final String? imageBase;

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
      MockScenario.store => const ChatConfig(
        botName: 'نجمة موبايل',
        statusText: 'موبايلات وإكسسوارات بكفالة',
        palette: TenantPalette(primary: Color(0xFF3346B8)),
      ),
    };
  }

  @override
  Future<ChatTurn?> current() async {
    final s = _state;
    if (s == null) return null;
    await _wait();
    return _step(s, redisplay: true);
  }

  @override
  Future<ChatTurn> start() async {
    await _wait();
    _day = '';
    _time = '';
    _cart.clear();
    _form.clear();
    _page = 0;
    return _step(_welcome);
  }

  @override
  Future<ChatTurn> continueConversation() async {
    await _wait();
    return _step(switch (scenario) {
      MockScenario.bakery => 'b.welcome',
      MockScenario.clinic => 'c.menu',
      MockScenario.store => 's.welcome',
    });
  }

  @override
  Future<HandoffLink> handoffLink() async {
    await _wait();
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
    if (body is ActionReply) return _action(s, body);
    final option = switch (body) {
      OptionReply(:final optionId) => optionId,
      TextReply(:final text) => _optionFromNumber(s, text),
      ActionReply() => null,
    };
    final text = body is TextReply ? body.text.trim() : '';

    switch (s) {
      case 'b.welcome':
      case 'b.hours':
        return switch (option) {
          'b.order' => _step('b.shop'),
          'b.hours' => _step('b.hours'),
          'b.track' => _step('b.track'),
          'b.back' => _step('b.welcome', redisplay: true),
          _ => _retry(s),
        };
      case 's.welcome':
        return option != null && option.startsWith('s.k.')
            ? _step('s.budget')
            : option == 's.human'
            ? _step('s.human')
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
      case 'b.shop':
        add(_t('تكرم عينك! هي قائمة اليوم، كلها طازة من الفرن 👇'));
        prompt = _catalogPrompt();
      case 'b.cart':
        prompt = _cartPrompt();
      case 'b.checkout':
        add(_t('آخر خطوة: عبّي بيانات الطلب 📝'));
        prompt = _checkoutPrompt(const {});
      case 'b.done':
        messages.add(_t('تمام، وصل طلبك! 🎉'));
        messages.add(
          _t(
            extra == 'delivery'
                ? 'رح يوصلك خلال ساعة تقريباً. صحتين وعافية!'
                : 'رح يكون جاهز بعد نص ساعة. منستناك!',
            card: StatusCard(
              title:
                  'طلب رقم 1042 · ${_money(_cartTotal() + (extra == 'delivery' ? 5000 : 0))}',
              status: 'قيد التحضير',
              tone: StatusTone.success,
            ),
          ),
        );
        prompt = const EndPrompt();

      case 's.welcome':
        add(_t('أهلاً فيك بنجمة موبايل 👋', typingMs: 500));
        add(_t('خلّينا نلاقيلك الجهاز المناسب. شو بدك؟'));
        prompt = const MenuPrompt(
          options: [
            MenuOption(id: 's.k.phone', label: 'موبايل 📱', index: 1),
            MenuOption(id: 's.k.tablet', label: 'تابلت', index: 2),
            MenuOption(id: 's.human', label: 'بدي احكي مع حدا', index: 3),
          ],
        );
      case 's.budget':
        add(_t('قديش ميزانيتك تقريباً؟ (بالدولار)'));
        prompt = const FormPrompt(
          isRange: true,
          title: 'الميزانية',
          submitLabel: 'تمام',
          fields: [
            FormFieldSpec(name: 'min', label: 'من', placeholder: '100'),
            FormFieldSpec(name: 'max', label: 'لحد', placeholder: '500'),
          ],
        );
      case 's.results':
        add(
          _t(_page == 0 ? 'لقينالك هدول 👇 اسحب لتشوف الكل.' : 'وهدول كمان 👇'),
        );
        prompt = _resultsPrompt();
      case 's.done':
        messages.add(
          _t(
            'تمام! حجزنالك ياه 👌',
            card: StatusCard(
              title: extra ?? '',
              status: 'محجوز إلك 24 ساعة',
              tone: StatusTone.success,
            ),
          ),
        );
        messages.add(_t('مرّ على المحل أو اطلب توصيل، ورح نتواصل معك.'));
        prompt = const EndPrompt();
      case 's.human':
        add(_t('رح يحكيك حدا من فريقنا بأقرب وقت 🙏'));
        prompt = const PausedPrompt(code: '61204-33871');
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

  String get _welcome => switch (scenario) {
    MockScenario.bakery => 'b.welcome',
    MockScenario.clinic => 'c.welcome',
    MockScenario.store => 's.welcome',
  };

  // --- Bakery shop (native catalogue, cart, checkout) ----------------------

  final List<_Line> _cart = [];
  final Map<String, String> _form = {};
  int _lineSeq = 0;

  String? _img(String file) =>
      imageBase == null ? null : '$imageBase/$file.png';

  List<Product> get _products => [
    Product(
      id: 'p.croissant',
      name: 'كرواسون زعتر',
      category: 'k.pastry',
      description: 'عجينة زبدة مقرمشة محشية زعتر بلدي.',
      price: '6,000 ل.س',
      unit: 'قطعة',
      max: 20,
      imageUrl: _img('croissant'),
      groups: const [
        ProductGroup(
          name: 'الحشوة',
          required: true,
          choices: [
            ProductChoice(id: 'o.zaatar', name: 'زعتر بس'),
            ProductChoice(
              id: 'o.cheese',
              name: 'زعتر وجبنة',
              price: '+1,000 ل.س',
            ),
          ],
        ),
      ],
    ),
    Product(
      id: 'p.manakish',
      name: 'منقوشة جبنة',
      category: 'k.pastry',
      description: 'جبنة عكاوي على عجينة رقيقة من الفرن.',
      price: '9,000 ل.س',
      unit: 'قطعة',
      max: 20,
      imageUrl: _img('manakish'),
    ),
    Product(
      id: 'p.kaak',
      name: 'كعك بسمسم',
      category: 'k.bread',
      description: 'كعك القدس بسمسم محمّص.',
      price: '8,000 ل.س',
      unit: 'كيس',
      max: 10,
      imageUrl: _img('kaak'),
    ),
    Product(
      id: 'p.baguette',
      name: 'خبز فرنسي',
      category: 'k.bread',
      price: '5,000 ل.س',
      unit: 'رغيف',
      max: 10,
      imageUrl: _img('baguette'),
    ),
    Product(
      id: 'p.maamoul',
      name: 'معمول بالتمر',
      category: 'k.sweets',
      description: 'معمول بيتي بالسمن العربي، بالكيلو.',
      price: '120,000 ل.س',
      unit: 'كيلو',
      step: 0.25,
      max: 5,
      imageUrl: _img('maamoul'),
    ),
    Product(
      id: 'p.cake',
      name: 'كيك برتقال',
      category: 'k.sweets',
      price: '45,000 ل.س',
      unit: 'قالب',
      max: 5,
      imageUrl: _img('cake'),
    ),
    Product(
      id: 'p.donut',
      name: 'دونات شوكولا',
      category: 'k.sweets',
      price: '7,000 ل.س',
      unit: 'قطعة',
      max: 20,
      imageUrl: _img('donut'),
    ),
    Product(
      id: 'p.basbousa',
      name: 'بسبوسة بالقشطة',
      category: 'k.sweets',
      price: '15,000 ل.س',
      unit: 'قطعة',
      available: false,
      imageUrl: _img('basbousa'),
    ),
  ];

  static const _prices = {
    'p.croissant': 6000,
    'p.manakish': 9000,
    'p.kaak': 8000,
    'p.baguette': 5000,
    'p.maamoul': 120000,
    'p.cake': 45000,
    'p.donut': 7000,
    'p.basbousa': 15000,
  };

  int _cartTotal() =>
      _cart.fold(0, (sum, l) => sum + (l.unitPrice * l.qty).round());

  static String _money(num v) {
    final s = v.round().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return '$b ل.س';
  }

  ProductListPrompt _catalogPrompt() => ProductListPrompt(
    categories: const [
      ProductCategory(id: 'k.pastry', name: 'معجنات'),
      ProductCategory(id: 'k.bread', name: 'خبز'),
      ProductCategory(id: 'k.sweets', name: 'حلويات'),
    ],
    products: _products,
    cartCount: _cart.length,
    cartTotal: _cart.isEmpty ? null : _money(_cartTotal()),
    doneLabel: 'عرض السلة',
  );

  CartPrompt _cartPrompt() => CartPrompt(
    lines: [
      for (final l in _cart)
        CartLine(
          id: l.id,
          name: l.product.name,
          options: l.options.isEmpty ? null : l.options.join('، '),
          qty: l.qty,
          step: l.product.step,
          max: l.product.max,
          unit: l.product.unit,
          unitPrice: _money(l.unitPrice),
          total: _money(l.unitPrice * l.qty),
        ),
    ],
    subtotal: _cart.isEmpty ? null : _money(_cartTotal()),
    canCheckout: _cart.isNotEmpty,
    moreLabel: 'إضافة منتجات',
    confirmLabel: 'تأكيد الطلب',
    emptyText: 'السلة فاضية. ضيف شي من القائمة.',
  );

  static const _zones = [
    FieldOption(id: 'z.mazzeh', label: 'المزة', hint: 'أجرة التوصيل 5,000 ل.س'),
    FieldOption(
      id: 'z.malki',
      label: 'المالكي',
      hint: 'أجرة التوصيل 5,000 ل.س',
    ),
    FieldOption(
      id: 'z.qassaa',
      label: 'القصاع',
      hint: 'أجرة التوصيل 5,000 ل.س',
    ),
  ];

  FormPrompt _checkoutPrompt(Map<String, String> errors) {
    String? v(String k) => _form[k];
    const delivery = 'delivery';
    return FormPrompt(
      title: 'بيانات الطلب',
      submitLabel: 'إرسال الطلب',
      openLabel: 'عبّي بيانات الطلب',
      error: errors.isEmpty ? null : 'في معلومات ناقصة، شوف الحقول المعلّمة.',
      summary: [
        LabelValue('المنتجات', '${_cart.length}'),
        LabelValue('المجموع', _money(_cartTotal())),
      ],
      fields: [
        FormFieldSpec(
          name: 'fulfillment',
          label: 'طريقة الاستلام',
          type: FormFieldKind.choice,
          required: true,
          value: v('fulfillment') ?? delivery,
          error: errors['fulfillment'],
          options: const [
            FieldOption(id: delivery, label: 'توصيل للبيت 🛵'),
            FieldOption(id: 'pickup', label: 'استلام من المحل'),
          ],
        ),
        FormFieldSpec(
          name: 'zone',
          label: 'المنطقة',
          type: FormFieldKind.choice,
          required: true,
          value: v('zone'),
          error: errors['zone'],
          options: _zones,
          showIfField: 'fulfillment',
          showIfValue: delivery,
        ),
        FormFieldSpec(
          name: 'address',
          label: 'العنوان',
          type: FormFieldKind.textarea,
          required: true,
          value: v('address'),
          error: errors['address'],
          placeholder: 'الشارع، البناية، الطابق',
          showIfField: 'fulfillment',
          showIfValue: delivery,
        ),
        FormFieldSpec(
          name: 'time',
          label: 'الوقت',
          type: FormFieldKind.choice,
          required: true,
          value: v('time') ?? 'asap',
          options: const [
            FieldOption(id: 'asap', label: 'بأقرب وقت'),
            FieldOption(id: 't.18', label: 'اليوم 6:00 المسا'),
            FieldOption(id: 't.20', label: 'اليوم 8:00 المسا'),
          ],
        ),
        FormFieldSpec(
          name: 'name',
          label: 'الاسم',
          required: true,
          value: v('name'),
          error: errors['name'],
        ),
        FormFieldSpec(
          name: 'phone',
          label: 'رقم الموبايل',
          type: FormFieldKind.phone,
          required: true,
          value: v('phone'),
          error: errors['phone'],
          placeholder: '09xxxxxxxx',
        ),
        FormFieldSpec(
          name: 'notes',
          label: 'ملاحظات',
          type: FormFieldKind.textarea,
          value: v('notes'),
          placeholder: 'مثلاً: بلا سمسم',
        ),
      ],
    );
  }

  ChatTurn _action(String state, ActionReply a) {
    final err = 'هالخطوة خلصت. اختار من يلي قدامك.';
    switch ((state, a.type)) {
      case ('b.shop', 'add'):
        final p = _products.where((x) => x.id == a.product).firstOrNull;
        if (p == null || !p.available) {
          return _step(state, error: 'هالمنتج مو متوفر هلأ.', redisplay: true);
        }
        final picked = a.options ?? const [];
        final names = <String>[];
        var extra = 0;
        for (final g in p.groups) {
          final c = g.choices.where((c) => picked.contains(c.id)).firstOrNull;
          if (c == null && g.required) {
            return _step(
              state,
              error: 'اختار ${g.name} لو سمحت.',
              redisplay: true,
            );
          }
          if (c != null) {
            names.add(c.name);
            if (c.id == 'o.cheese') extra += 1000;
          }
        }
        final qty = (a.qty ?? 1).clamp(p.step, p.max);
        final same =
            _cart
                .where(
                  (l) =>
                      l.product.id == p.id && l.options.join() == names.join(),
                )
                .firstOrNull;
        if (same != null) {
          same.qty = (same.qty + qty).clamp(p.step, p.max);
        } else {
          _cart.add(
            _Line(
              'l${++_lineSeq}',
              p,
              names,
              (_prices[p.id] ?? 0) + extra,
              qty,
            ),
          );
        }
        return _step('b.shop', redisplay: true);
      case ('b.shop', 'done'):
        return _cart.isEmpty
            ? _step('b.shop', error: 'السلة فاضية.', redisplay: true)
            : _step('b.cart');
      case ('b.cart', 'set_qty'):
        final l = _cart.where((x) => x.id == a.line).firstOrNull;
        if (l != null) {
          l.qty = (a.qty ?? l.qty).clamp(l.product.step, l.product.max);
        }
        return _step('b.cart');
      case ('b.cart', 'remove'):
        _cart.removeWhere((x) => x.id == a.line);
        return _step('b.cart');
      case ('b.cart', 'more'):
        return _step('b.shop', redisplay: true);
      case ('b.cart', 'confirm'):
        return _cart.isEmpty ? _step('b.cart') : _step('b.checkout');
      case ('b.checkout', 'submit'):
        final v = a.values ?? const {};
        _form
          ..clear()
          ..addAll(v);
        final errors = <String, String>{};
        final delivery = v['fulfillment'] == 'delivery';
        if (v['fulfillment'] != 'delivery' && v['fulfillment'] != 'pickup') {
          errors['fulfillment'] = 'هالحقل مطلوب.';
        }
        if (delivery && !_zones.any((z) => z.id == v['zone'])) {
          errors['zone'] = 'هالحقل مطلوب.';
        }
        if (delivery && (v['address'] ?? '').trim().length < 5) {
          errors['address'] = 'العنوان قصير، زيد تفاصيل.';
        }
        if ((v['name'] ?? '').trim().length < 2) {
          errors['name'] = 'هالحقل مطلوب.';
        }
        if (!_validPhone(v['phone'] ?? '')) {
          errors['phone'] = 'الرقم مو صحيح. اكتبه بالشكل 09xxxxxxxx.';
        }
        if (errors.isNotEmpty) {
          _state = 'b.checkout';
          return ChatTurn(messages: const [], prompt: _checkoutPrompt(errors));
        }
        return _step('b.done', extra: v['fulfillment']);
      case ('s.budget', 'submit'):
        _page = 0;
        return _step('s.results');
      case ('s.results', 'more'):
        _page++;
        return _step('s.results');
      case ('s.results', 'select'):
        final p = _phones.where((x) => x.id == a.product).firstOrNull;
        if (p == null) return _step(state, error: err, redisplay: true);
        return _step('s.done', extra: '${p.name} · ${p.price}');
      case ('s.results', 'restart'):
        return _step('s.welcome');
      case ('s.results', 'contact'):
        return _step('s.human');
      default:
        return _step(state, error: err, redisplay: true);
    }
  }

  // --- Store finder (range + pick) -------------------------------------------

  int _page = 0;

  List<Product> get _phones => [
    for (final (i, d)
        in const [
          ('نوفا X5', '\$249', '6.5 إنش', '5000 mAh', '128GB', 'NX5-128'),
          ('لومن A3', '\$189', '6.1 إنش', '4500 mAh', '64GB', 'LA3-64'),
          ('بيكسو 9', '\$329', '6.7 إنش', '5200 mAh', '256GB', 'PX9-256'),
          ('أورا M2', '\$279', '6.4 إنش', '4800 mAh', '128GB', 'OM2-128'),
          ('نوفا X5 برو', '\$399', '6.8 إنش', '5500 mAh', '256GB', 'NX5P-256'),
          ('لومن A5', '\$219', '6.3 إنش', '5000 mAh', '128GB', 'LA5-128'),
        ].indexed)
      Product(
        id: 'ph.$i',
        name: d.$1,
        categoryName: 'موبايل',
        price: d.$2,
        priceHint: 'كفالة سنة · توصيل مجاني',
        code: d.$6,
        imageUrl: _img('phone${i % 3 + 1}'),
        attributes: [LabelValue('الشاشة', d.$3), LabelValue('البطارية', d.$4)],
        details: [
          LabelValue('الذاكرة', d.$5),
          const LabelValue('الشبكة', '4G / 5G'),
          const LabelValue('اللون', 'أسود، أزرق'),
        ],
      ),
  ];

  ProductListPrompt _resultsPrompt() {
    final all = _phones;
    final shown = all.skip(_page * 3).take(3).toList();
    return ProductListPrompt(
      isPick: true,
      products: shown,
      total: all.length,
      hasMore: (_page + 1) * 3 < all.length,
      moreLabel: 'عرض المزيد',
      selectLabel: 'بدي هاد',
      detailsLabel: 'التفاصيل',
      restartLabel: 'ابدأ من جديد',
      contactLabel: 'احكي مع حدا',
    );
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

class _Line {
  _Line(this.id, this.product, this.options, this.unitPrice, this.qty);

  final String id;
  final Product product;
  final List<String> options;
  final num unitPrice;
  num qty;
}
