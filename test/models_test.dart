import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:raselna_chat/raselna_chat.dart';

void main() {
  group('Prompt.fromJson', () {
    test('menu with 1-3 options shows buttons, 4+ a list', () {
      final three =
          Prompt.fromJson({
                'kind': 'menu',
                'display': 'buttons',
                'options': [
                  {'id': 'a', 'label': 'A', 'index': 1},
                  {'id': 'b', 'label': 'B', 'index': 2},
                ],
              })
              as MenuPrompt;
      expect(three.display, MenuDisplay.buttons);
      expect(three.options.map((o) => o.id), ['a', 'b']);

      final four =
          Prompt.fromJson({
                'kind': 'menu',
                'options': [
                  for (var i = 1; i <= 4; i++)
                    {'id': 'o$i', 'label': 'L$i', 'index': i},
                ],
              })
              as MenuPrompt;
      expect(four.display, MenuDisplay.list);
    });

    test('input types map to keyboards; password never stays native', () {
      expect(
        (Prompt.fromJson({'kind': 'input', 'input_type': 'tel'}) as InputPrompt)
            .inputKind,
        InputKind.phone,
      );
      expect(
        (Prompt.fromJson({'kind': 'input', 'input_type': 'email'})
                as InputPrompt)
            .inputKind,
        InputKind.email,
      );
      final progress =
          Prompt.fromJson({
                'kind': 'input',
                'input_type': 'number',
                'progress': {'step': 2, 'total': 4},
              })
              as InputPrompt;
      expect(progress.inputKind, InputKind.number);
      expect(progress.progress!.step, 2);

      final secret = Prompt.fromJson({
        'kind': 'input',
        'input_type': 'password',
      });
      expect(secret, isA<HandoffPrompt>());
      expect((secret as HandoffPrompt).reason, HandoffReason.secret);
    });

    test('rich and unknown kinds become a handoff, never a crash', () {
      expect(
        (Prompt.fromJson({
                  'kind': 'product_list',
                  'products': [{}, {}],
                })
                as HandoffPrompt)
            .count,
        2,
      );
      expect(
        (Prompt.fromJson({'kind': 'cart'}) as HandoffPrompt).reason,
        HandoffReason.cart,
      );
      expect(
        (Prompt.fromJson({'kind': 'form'}) as HandoffPrompt).reason,
        HandoffReason.form,
      );
      final future = Prompt.fromJson({'kind': 'hologram_3d'}) as HandoffPrompt;
      expect(future.reason, HandoffReason.unknown);
      expect(future.kind, 'hologram_3d');
    });

    test('slots, end, paused, none', () {
      final slots =
          Prompt.fromJson({
                'kind': 'slots',
                'title': 'الأوقات',
                'groups': [
                  {
                    'label': 'الصبح',
                    'options': [
                      {'id': 't1', 'label': '9:00'},
                      {'bad': true},
                    ],
                  },
                ],
                'actions': [
                  {'id': 'x', 'label': 'يوم تاني'},
                ],
              })
              as SlotsPrompt;
      expect(slots.groups.single.options.single.id, 't1');
      expect(slots.actions.single.label, 'يوم تاني');
      expect(
        (Prompt.fromJson({'kind': 'end', 'show_restart': false}) as EndPrompt)
            .showRestart,
        isFalse,
      );
      expect(
        (Prompt.fromJson({'kind': 'paused', 'code': '1-2'}) as PausedPrompt)
            .code,
        '1-2',
      );
      expect(Prompt.fromJson({}), isA<NonePrompt>());
    });
  });

  group('ChatTurn.fromJson', () {
    test('handoff.required overrides the prompt; secret wins', () {
      final menu = ChatTurn.fromJson({
        'prompt': {'kind': 'menu', 'display': 'buttons', 'options': []},
        'handoff': {'required': true, 'reason': 'rich_step'},
      });
      expect(menu.prompt, isA<HandoffPrompt>());
      final secret = ChatTurn.fromJson({
        'prompt': {'kind': 'input', 'input_type': 'national_id'},
        'handoff': {'required': true, 'reason': 'secret'},
      });
      expect((secret.prompt as HandoffPrompt).reason, HandoffReason.secret);
      final unknownInput = ChatTurn.fromJson({
        'prompt': {'kind': 'input', 'input_type': 'username'},
      });
      expect((unknownInput.prompt as InputPrompt).inputKind, InputKind.text);
    });

    test('keeps known messages, drops unknown types and unsafe images', () {
      final t = ChatTurn.fromJson({
        'messages': [
          {
            'id': '1',
            'type': 'text',
            'text': 'hi',
            'typing_ms': 400,
            'card': {'title': 'طلب 1', 'status': 'جاهز', 'tone': 'success'},
          },
          {'id': '2', 'type': 'image', 'url': 'javascript:alert(1)'},
          {
            'id': '3',
            'type': 'image',
            'url': 'https://x.raselna.com/a.webp',
            'alt': 'خبز',
          },
          {'id': '4', 'type': 'push_optin'},
          {'id': '5', 'type': 'status', 'text': 'تم'},
        ],
        'prompt': {'kind': 'none'},
      });
      expect(t.messages, hasLength(3));
      final text = t.messages.first as TextMessage;
      expect(text.typingMs, 400);
      expect(text.card!.tone, StatusTone.success);
      expect((t.messages[1] as ImageMessage).alt, 'خبز');
    });
  });

  group('ChatConfig and colours', () {
    test('parses #rrggbb only', () {
      expect(parseHexColor('#C2410C'), const Color(0xFFC2410C));
      for (final bad in [
        'red',
        '#abc',
        'C2410C',
        '#c2410c;background:url(x)',
        null,
        12,
      ]) {
        expect(parseHexColor(bad), isNull, reason: '$bad');
      }
    });

    test('config reads the palette and drops non-http logos', () {
      final c = ChatConfig.fromJson({
        'bot_name': 'فرن الياسمين',
        'logo_url': 'file:///etc/passwd',
        'powered_by': false,
        'colors': {'primary': '#b4441a', 'primary_fg': '#ffffff'},
        'features': {'resume': true, 'push': false},
      });
      expect(c.logoUrl, isNull);
      expect(c.poweredBy, isFalse);
      expect(c.palette!.primary, const Color(0xFFB4441A));
      expect(c.canResume, isTrue);
      expect(c.avatarInitial, 'ف');
    });

    test('derived tones meet contrast on light and dark', () {
      for (final hex in [
        '#FFE066',
        '#FFFFFF',
        '#B4441A',
        '#0F766E',
        '#111133',
        '#9AE6B4',
      ]) {
        final p = derivePalette(parseHexColor(hex)!);
        expect(
          contrastRatio(p.onPrimary, parseHexColor(hex)!),
          greaterThanOrEqualTo(4.5),
          reason: hex,
        );
        expect(
          contrastRatio(p.strong, const Color(0xFFFFFFFF)),
          greaterThanOrEqualTo(4.5),
          reason: hex,
        );
        expect(
          contrastRatio(p.dark, const Color(0xFF1A1B23)),
          greaterThanOrEqualTo(4.5),
          reason: hex,
        );
      }
    });
  });

  group('validateAnswer', () {
    const s = RaselnaStrings.ar;
    test('phone', () {
      expect(validateAnswer(InputKind.phone, '12', s), s.invalidPhone);
      expect(validateAnswer(InputKind.phone, '0991 234 567', s), isNull);
      expect(validateAnswer(InputKind.phone, '+963 991 234 567', s), isNull);
      expect(validateAnswer(InputKind.phone, '٠٩٩١٢٣٤٥٦٧', s), isNull);
      expect(validateAnswer(InputKind.phone, 'call me', s), s.invalidPhone);
    });
    test('number, email, empty', () {
      expect(validateAnswer(InputKind.number, '١٠٤٢', s), isNull);
      expect(validateAnswer(InputKind.number, '12a', s), s.invalidNumber);
      expect(validateAnswer(InputKind.email, 'a@b.co', s), isNull);
      expect(validateAnswer(InputKind.email, 'a@b', s), s.invalidEmail);
      expect(validateAnswer(InputKind.text, '   ', s), s.invalidEmpty);
    });
    test('normalizes Arabic-Indic digits', () {
      expect(normalizeDigits('٠٩٩ ۱۲۳'), '099 123');
    });
  });
}
