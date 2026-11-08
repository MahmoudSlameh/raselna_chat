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
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.light),
      home: Scaffold(body: RaselnaChatView(controller: ctl, themeMode: mode)),
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
      find.byType(RaselnaChatView),
      matchesGoldenFile('goldens/bakery_welcome_light.png'),
    );
  });

  testWidgets('bakery catalog handoff, light', (tester) async {
    await _drive(tester, MockScenario.bakery, ThemeMode.light, (c) async {
      await c.choose((c.prompt as MenuPrompt).options.first);
    });
    await expectLater(
      find.byType(RaselnaChatView),
      matchesGoldenFile('goldens/bakery_handoff_light.png'),
    );
  });

  testWidgets('bakery confirmation, dark', (tester) async {
    await _drive(tester, MockScenario.bakery, ThemeMode.dark, (c) async {
      await c.choose((c.prompt as MenuPrompt).options.first);
      await c.openHandoff();
      await c.sendText('0991234567');
      await c.choose((c.prompt as MenuPrompt).options.first);
    });
    await expectLater(
      find.byType(RaselnaChatView),
      matchesGoldenFile('goldens/bakery_done_dark.png'),
    );
  });

  testWidgets('clinic time slots, light', (tester) async {
    await _drive(tester, MockScenario.clinic, ThemeMode.light, (c) async {
      await c.choose((c.prompt as MenuPrompt).options.first);
      await c.choose((c.prompt as MenuPrompt).options.first);
      await c.chooseSlot((c.prompt as SlotsPrompt).groups.single.options[3]);
    });
    await expectLater(
      find.byType(RaselnaChatView),
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
      find.byType(RaselnaChatView),
      matchesGoldenFile('goldens/clinic_phone_dark.png'),
    );
  });

  testWidgets('clinic paused card, light', (tester) async {
    await _drive(tester, MockScenario.clinic, ThemeMode.light, (c) async {
      await c.choose((c.prompt as MenuPrompt).options[3]);
    });
    await expectLater(
      find.byType(RaselnaChatView),
      matchesGoldenFile('goldens/clinic_paused_light.png'),
    );
  });
}
