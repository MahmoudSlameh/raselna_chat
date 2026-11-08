import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:raselna_chat/raselna_chat.dart';

/// raselna_chat demo.
///
/// By default it plays a scripted conversation with [MockTransport] (no
/// network, no account). Flip "Use a real key" to talk to your own Raselna
/// bot with your publishable key.
///
/// On the web, `?shot=<name>` opens a chat state directly (used for the
/// README screenshots): welcome, menu, catalog, slots, confirm, dark.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final shot = Uri.base.queryParameters['shot'];
  if (shot != null) {
    runApp(ShotApp(shot: shot));
    return;
  }
  await RaselnaChat.init(
    accessKey: 'rpk_test_demo',
    transport: MockTransport(),
    store: MemoryStore(),
  );
  runApp(const DemoApp());
}

const _ink = Color(0xFF202060);
const _indigo = Color(0xFF4B4BC8);

ThemeData _theme(Brightness b) => ThemeData(
  brightness: b,
  colorScheme: ColorScheme.fromSeed(seedColor: _indigo, brightness: b),
  fontFamily: 'Tajawal',
  package: 'raselna_chat',
);

class DemoApp extends StatefulWidget {
  const DemoApp({super.key});

  @override
  State<DemoApp> createState() => _DemoAppState();
}

class _DemoAppState extends State<DemoApp> {
  MockScenario _scenario = MockScenario.bakery;
  bool _real = false;
  bool _dark = false;
  final _key = TextEditingController(text: 'rpk_test_');
  final _url = TextEditingController(text: 'https://api.raselna.com');
  String? _error;

  Future<void> _apply() async {
    setState(() => _error = null);
    try {
      if (_real) {
        await RaselnaChat.init(
          accessKey: _key.text.trim(),
          baseUrl: Uri.parse(_url.text.trim()),
          themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
        );
      } else {
        await RaselnaChat.init(
          accessKey: 'rpk_test_demo',
          transport: MockTransport(scenario: _scenario),
          store: MemoryStore(),
          themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
        );
      }
    } on ArgumentError catch (e) {
      setState(() => _error = e.message?.toString());
    }
    setState(() {});
  }

  @override
  void dispose() {
    _key.dispose();
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'raselna_chat',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Builder(
        builder:
            (context) => Scaffold(
              appBar: AppBar(
                title: const Text('raselna_chat · Flutter'),
                backgroundColor: _ink,
                foregroundColor: Colors.white,
              ),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'جرّب الشات بمحادثة وهمية (بلا إنترنت)، أو حط مفتاحك العام.',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<MockScenario>(
                    segments: const [
                      ButtonSegment(
                        value: MockScenario.bakery,
                        label: Text('مخبز'),
                        icon: Icon(Icons.bakery_dining_outlined),
                      ),
                      ButtonSegment(
                        value: MockScenario.clinic,
                        label: Text('عيادة'),
                        icon: Icon(Icons.medical_services_outlined),
                      ),
                    ],
                    selected: {_scenario},
                    onSelectionChanged:
                        _real
                            ? null
                            : (s) {
                              _scenario = s.first;
                              _apply();
                            },
                  ),
                  SwitchListTile(
                    title: const Text('الوضع الليلي'),
                    value: _dark,
                    onChanged: (v) {
                      _dark = v;
                      _apply();
                    },
                  ),
                  SwitchListTile(
                    title: const Text('استعمل مفتاح حقيقي'),
                    subtitle: const Text(
                      'Publishable key only (rpk_live_… / rpk_test_…)',
                    ),
                    value: _real,
                    onChanged: (v) => setState(() => _real = v),
                  ),
                  if (_real) ...[
                    TextField(
                      controller: _key,
                      textDirection: TextDirection.ltr,
                      decoration: const InputDecoration(
                        labelText: 'Publishable key',
                      ),
                    ),
                    TextField(
                      controller: _url,
                      textDirection: TextDirection.ltr,
                      decoration: const InputDecoration(labelText: 'Base URL'),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonal(
                      onPressed: _apply,
                      child: const Text('تطبيق'),
                    ),
                  ],
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => RaselnaChat.open(context),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('افتح الشات (شاشة كاملة)'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed:
                        () => RaselnaChat.open(context, asBottomSheet: true),
                    icon: const Icon(Icons.vertical_align_top),
                    label: const Text('افتح الشات (ورقة من تحت)'),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'أو كـ widget جوّا شاشتك:',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      height: 520,
                      // A key per setup, so the embedded view picks up re-inits.
                      child: RaselnaChatView(
                        key: ValueKey(RaselnaChat.controller),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      ),
    );
  }
}

/// One chat state, full screen, for screenshots (`?shot=…`).
class ShotApp extends StatefulWidget {
  const ShotApp({super.key, required this.shot});

  final String shot;

  @override
  State<ShotApp> createState() => _ShotAppState();
}

class _ShotAppState extends State<ShotApp> {
  late final RaselnaChatController _ctl;
  late final bool _dark = widget.shot == 'dark';

  MockScenario get _scenario => switch (widget.shot) {
    'welcome' || 'slots' || 'confirm' => MockScenario.clinic,
    _ => MockScenario.bakery,
  };

  @override
  void initState() {
    super.initState();
    _ctl = RaselnaChatController(
      transport: MockTransport(
        scenario: _scenario,
        latency: Duration.zero,
        typing: false,
      ),
      animateTyping: false,
    );
    _play();
  }

  Future<void> _play() async {
    final c = _ctl;
    await c.load();
    Future<void> pick(int i) => c.choose((c.prompt as MenuPrompt).options[i]);
    Future<void> slot(int g, int i) =>
        c.chooseSlot((c.prompt as SlotsPrompt).groups[g].options[i]);
    switch (widget.shot) {
      case 'catalog':
        await pick(0);
      case 'slots':
        await pick(0);
        await pick(0);
        await slot(0, 3);
      case 'confirm':
        await pick(0);
        await pick(0);
        await slot(0, 3);
        await slot(0, 2);
        await c.sendText('سلمى الأحمد');
        await c.sendText('0991234567');
      case 'dark':
        await pick(0);
        await c.openHandoff();
        await c.sendText('0991234567');
        await pick(0);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Scaffold(
        body: RaselnaChatView(
          controller: _ctl,
          themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
          onClose: () {},
        ),
      ),
    );
  }
}
