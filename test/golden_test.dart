// RTL golden tests at a phone size (390x844), light and dark.
//
// Regenerate with: flutter test --update-goldens test/golden_test.dart
// Goldens are rendered on Linux; text rasterises slightly differently on
// other systems, so CI runs them on Linux only (tag: golden).
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raselna_chat/raselna_chat.dart';

import 'helpers.dart';

const _app = ValueKey('app');

Future<RaselnaChatController> _drive(
  WidgetTester tester,
  MockScenario scenario,
  ThemeMode mode,
  Future<void> Function(RaselnaChatController c) steps,
) async {
  tester.view.physicalSize = const Size(390 * 2, 844 * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  final ctl = controllerFor(
    MockTransport(scenario: scenario, latency: Duration.zero, typing: false),
  );
  addTearDown(ctl.dispose);
  await tester.pumpWidget(
    RepaintBoundary(
      key: _app,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(brightness: Brightness.light),
        home: Scaffold(body: RaselnaChatView(controller: ctl, themeMode: mode)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.runAsync(() => steps(ctl));
  await tester.pumpAndSettle();
  return ctl;
}

void main() {
  setUpAll(loadTestFonts);

  testWidgets('bakery welcome, light', (tester) async {
    await _drive(tester, MockScenario.bakery, ThemeMode.light, (_) async {});
    await expectLater(
      find.byKey(_app),
      matchesGoldenFile('goldens/bakery_welcome_light.png'),
    );
  });

  Future<void> shop(RaselnaChatController c) async {
    await c.choose((c.prompt as MenuPrompt).options.first);
  }

  Future<void> cart(RaselnaChatController c) async {
    await shop(c);
    await c.act(
      const ActionReply(
        'add',
        product: 'p.croissant',
        qty: 2,
        options: ['o.cheese'],
      ),
      echo: '➕ 2 × كرواسون زعتر',
    );
    await c.act(
      const ActionReply('add', product: 'p.maamoul', qty: 0.75),
      echo: '➕ 0.75 × معمول بالتمر',
    );
    await c.act(const ActionReply('done'), echo: 'عرض السلة');
  }

  testWidgets('bakery native catalogue, light', (tester) async {
    await _drive(tester, MockScenario.bakery, ThemeMode.light, shop);
    await expectLater(
      find.byKey(_app),
      matchesGoldenFile('goldens/bakery_catalog_light.png'),
    );
  });

  testWidgets('bakery catalogue sheet, light', (tester) async {
    await _drive(tester, MockScenario.bakery, ThemeMode.light, shop);
    await tester.tap(find.text('تصفّح القائمة'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(_app),
      matchesGoldenFile('goldens/bakery_sheet_light.png'),
    );
  });

  testWidgets('bakery cart, light', (tester) async {
    await _drive(tester, MockScenario.bakery, ThemeMode.light, cart);
    await expectLater(
      find.byKey(_app),
      matchesGoldenFile('goldens/bakery_cart_light.png'),
    );
  });

  testWidgets('bakery checkout form, light', (tester) async {
    await _drive(tester, MockScenario.bakery, ThemeMode.light, (c) async {
      await cart(c);
      await c.act(const ActionReply('confirm'), echo: 'تأكيد الطلب');
    });
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(_app),
      matchesGoldenFile('goldens/bakery_checkout_light.png'),
    );
  });

  testWidgets('bakery confirmation, dark', (tester) async {
    await _drive(tester, MockScenario.bakery, ThemeMode.dark, (c) async {
      await cart(c);
      await c.act(const ActionReply('confirm'), echo: 'تأكيد الطلب');
      await c.act(
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
        echo: '📝 أرسلت بيانات الطلب',
      );
    });
    await expectLater(
      find.byKey(_app),
      matchesGoldenFile('goldens/bakery_done_dark.png'),
    );
  });

  testWidgets('store finder results, dark', (tester) async {
    await _drive(tester, MockScenario.store, ThemeMode.dark, (c) async {
      await c.choose((c.prompt as MenuPrompt).options.first);
      await c.act(
        const ActionReply('submit', values: {'min': '150', 'max': '400'}),
        echo: '150 – 400',
      );
    });
    await expectLater(
      find.byKey(_app),
      matchesGoldenFile('goldens/store_results_dark.png'),
    );
  });

  testWidgets('clinic time slots, light', (tester) async {
    await _drive(tester, MockScenario.clinic, ThemeMode.light, (c) async {
      await c.choose((c.prompt as MenuPrompt).options.first);
      await c.choose((c.prompt as MenuPrompt).options.first);
      await c.chooseSlot((c.prompt as SlotsPrompt).groups.single.options[3]);
    });
    await expectLater(
      find.byKey(_app),
      matchesGoldenFile('goldens/clinic_slots_light.png'),
    );
  });

  testWidgets('clinic phone input with progress, dark', (tester) async {
    await _drive(tester, MockScenario.clinic, ThemeMode.dark, (c) async {
      await c.choose((c.prompt as MenuPrompt).options.first);
      await c.choose((c.prompt as MenuPrompt).options[1]);
      await c.chooseSlot((c.prompt as SlotsPrompt).groups.single.options[1]);
      await c.chooseSlot((c.prompt as SlotsPrompt).groups.last.options.last);
      await c.sendText('سلمى الأحمد');
    });
    await expectLater(
      find.byKey(_app),
      matchesGoldenFile('goldens/clinic_phone_dark.png'),
    );
  });

  testWidgets('clinic paused card, light', (tester) async {
    await _drive(tester, MockScenario.clinic, ThemeMode.light, (c) async {
      await c.choose((c.prompt as MenuPrompt).options[3]);
    });
    await expectLater(
      find.byKey(_app),
      matchesGoldenFile('goldens/clinic_paused_light.png'),
    );
  });
}
