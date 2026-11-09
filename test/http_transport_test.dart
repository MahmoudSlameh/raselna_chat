// HttpTransport against the chat API v1 contract (public/openapi/chat-v1.yaml).
// The JSON bodies in test/fixtures/ are validated against the contract's
// schemas (Config, DeviceCredential, Turn, HandoffLink).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:raselna_chat/raselna_chat.dart';

const _key = 'rpk_test_0123456789abcdefghijABCDEFGHIJ0123456789';
const _device =
    '01jdv8k3m4n5p6q7r8s9t0v1w2.aB3dE5fG7hJ9kL1mN3pQ5rS7tU9vW1xY3zA5bC7dE9fG1hJ3';

String fixture(String name) =>
    File('test/fixtures/$name.json').readAsStringSync();

http.Response ok(
  String fixtureName, [
  int status = 200,
  Map<String, String> headers = const {},
]) => http.Response.bytes(
  utf8.encode(fixture(fixtureName)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8', ...headers},
);

http.Response err(
  int status,
  String code, {
  String message = 'رسالة',
  Map<String, dynamic> extra = const {},
  Map<String, String> headers = const {},
}) => http.Response.bytes(
  utf8.encode(jsonEncode({'error': code, 'message': message, ...extra})),
  status,
  headers: {'content-type': 'application/json; charset=utf-8', ...headers},
);

void main() {
  late List<http.Request> requests;
  late MemoryStore store;

  HttpTransport transport(
    Future<http.Response> Function(http.Request r) handler, {
    String? appId,
    String? flow,
  }) => HttpTransport(
    accessKey: _key,
    store: store,
    appId: appId,
    flow: flow,
    client: MockClient((r) {
      requests.add(r);
      return handler(r);
    }),
  );

  setUp(() {
    requests = [];
    store = MemoryStore();
  });

  test(
    'registers the device once (POST /devices, 201), then sends the credential',
    () async {
      final t = transport(
        (r) async => switch (r.url.path) {
          '/v1/devices' => ok('device', 201),
          '/v1/conversations' => ok('turn_start', 201),
          _ => ok('turn_slots'),
        },
        appId: 'com.yasmin.bakery',
        flow: 'orders',
      );

      final first = await t.start();
      expect((first.prompt as MenuPrompt).options.first.id, 'q8Zr2xLm');
      expect(
        first.messages,
        hasLength(2),
        reason: 'push_optin is not a bubble',
      );
      expect(first.conversation!.id, '01jdv8m0a1b2c3d4e5f6g7h8j9');
      expect(first.conversation!.test, isTrue);

      await t.reply(const OptionReply('q8Zr2xLm'), idempotencyKey: 'idem-1');

      expect(requests.map((r) => '${r.method} ${r.url}'), [
        'POST https://api.raselna.com/v1/devices',
        'POST https://api.raselna.com/v1/conversations',
        'POST https://api.raselna.com/v1/conversations/current/reply',
      ]);
      final register = requests[0];
      expect(register.headers.containsKey('X-Raselna-Device'), isFalse);
      expect(jsonDecode(register.body), {
        'platform': 'android',
        'sdk_version': raselnaSdkVersion,
      });

      for (final r in requests) {
        expect(r.headers['X-Raselna-Key'], _key);
        expect(r.headers['X-Raselna-App'], 'com.yasmin.bakery');
        expect(r.headers['X-Raselna-SDK'], 'flutter/$raselnaSdkVersion');
        expect(
          r.headers.containsKey('Authorization'),
          isFalse,
          reason: 'v1 has no conversation token',
        );
        expect(r.url.hasQuery, isFalse, reason: 'nothing travels in a URL');
      }
      expect(requests[1].headers['X-Raselna-Device'], _device);
      expect(jsonDecode(requests[1].body), {'flow': 'orders'});
      expect(requests[2].headers['Idempotency-Key'], 'idem-1');
      expect(jsonDecode(requests[2].body), {'option_id': 'q8Zr2xLm'});
      expect(await store.read('device'), _device);
    },
  );

  test(
    'the device survives a restart: GET /conversations/current reuses it',
    () async {
      await store.write('device', _device);
      final t = transport((r) async => ok('turn_slots'));
      final turn = await t.current();
      expect(turn!.prompt, isA<SlotsPrompt>());
      expect(requests.single.method, 'GET');
      expect(requests.single.url.path, '/v1/conversations/current');
      expect(requests.single.headers['X-Raselna-Device'], _device);
    },
  );

  test(
    'no current conversation (404 conversation_not_found) or ended (410) is null',
    () async {
      await store.write('device', _device);
      expect(
        await transport(
          (r) async => err(404, 'conversation_not_found'),
        ).current(),
        isNull,
      );
      expect(
        await transport(
          (r) async =>
              err(410, 'session_ended', extra: {'status': 'completed'}),
        ).current(),
        isNull,
      );
    },
  );

  test('404 device_not_found registers again once and retries', () async {
    await store.write('device', 'old.revoked');
    var calls = 0;
    final t = transport((r) async {
      if (r.url.path == '/v1/devices') return ok('device', 201);
      calls++;
      return r.headers['X-Raselna-Device'] == 'old.revoked'
          ? err(404, 'device_not_found')
          : ok('turn_start', 201);
    });
    await t.start();
    expect(calls, 2);
    expect(requests.map((r) => r.url.path), [
      '/v1/conversations',
      '/v1/devices',
      '/v1/conversations',
    ]);
    expect(await store.read('device'), _device);
  });

  test('device_not_found twice in a row gives up (no loop)', () async {
    await store.write('device', 'old.revoked');
    final t = transport(
      (r) async =>
          r.url.path == '/v1/devices'
              ? ok('device', 201)
              : err(404, 'device_not_found'),
    );
    await expectLater(
      t.start(),
      throwsA(
        isA<RaselnaException>().having(
          (e) => e.code,
          'code',
          'device_not_found',
        ),
      ),
    );
    expect(
      requests.where((r) => r.url.path == '/v1/conversations'),
      hasLength(2),
    );
  });

  test(
    'declared rich steps are native; the server\'s handoff (rich_step, secret) wins',
    () async {
      await store.write('device', _device);
      final handedOff =
          await transport((r) async => ok('turn_catalog')).current();
      final h = handedOff!.prompt as HandoffPrompt;
      expect(h.reason, HandoffReason.catalog);
      expect(h.count, 2);

      final catalog =
          await transport((r) async => ok('turn_catalog_native')).current();
      final c = catalog!.prompt as ProductListPrompt;
      expect(c.products, hasLength(2));
      expect(c.products.first.name, 'كرواسون زعتر');
      expect(c.categories.single.name, 'معجنات');
      expect(
        requests.last.headers['X-Raselna-Capabilities'],
        'product_list,product_list.pick,cart,form,form.range,slots',
      );

      final secret = await transport((r) async => ok('turn_secret')).current();
      expect((secret!.prompt as HandoffPrompt).reason, HandoffReason.secret);
    },
  );

  test(
    'a rich-step action is sent as {action} with the idempotency key',
    () async {
      await store.write('device', _device);
      final t = transport((r) async => ok('turn_catalog'));
      await t.reply(
        const ActionReply('add', product: 'p1', qty: 0.25, options: ['o1']),
        idempotencyKey: 'idem-add',
      );
      expect(requests.last.headers['Idempotency-Key'], 'idem-add');
      expect(jsonDecode(requests.last.body), {
        'action': {
          'type': 'add',
          'product': 'p1',
          'qty': 0.25,
          'options': ['o1'],
        },
      });
      await t.reply(
        const ActionReply(
          'submit',
          values: {'name': 'سلمى', 'phone': '0991234567'},
        ),
        idempotencyKey: 'idem-submit',
      );
      expect(jsonDecode(requests.last.body), {
        'action': {
          'type': 'submit',
          'values': {'name': 'سلمى', 'phone': '0991234567'},
        },
      });
    },
  );

  test(
    'handoff-link returns an https one-use URL; anything else is refused',
    () async {
      await store.write('device', _device);
      final link =
          await transport((r) async => ok('handoff_link')).handoffLink();
      expect(link.url.toString(), 'https://yasmin.raselna.com/#h=Zt7Kq2');
      expect(link.expiresAt, DateTime.utc(2026, 11, 8, 10, 15));
      expect(requests.last.method, 'POST');
      expect(requests.last.url.path, '/v1/conversations/current/handoff-link');

      final bad = transport(
        (r) async => http.Response(
          jsonEncode({'url': 'http://evil.example/#h=1', 'expires_at': ''}),
          200,
        ),
      );
      await expectLater(bad.handoffLink(), throwsA(isA<RaselnaException>()));
    },
  );

  test(
    'config: colors, features and ETag (304 reuses the cached config)',
    () async {
      var n = 0;
      final t = transport((r) async {
        n++;
        return n == 1
            ? ok('config', 200, {'etag': '"v1"'})
            : http.Response('', 304);
      });
      final c = await t.config();
      expect(c.botName, 'فرن الياسمين');
      expect(c.palette!.primaryStrong, parseHexColor('#9a3a16'));
      expect(c.canResume, isTrue);
      expect(c.canPush, isFalse);
      expect(c.isTest, isTrue);
      expect(c.pattern, 'stars');
      expect(
        requests.first.headers.containsKey('X-Raselna-Device'),
        isFalse,
        reason: '/config needs no device',
      );

      final again = await t.config();
      expect(identical(again, c), isTrue);
      expect(requests.last.headers['If-None-Match'], '"v1"');
    },
  );

  test('errors keep code, status, message, reason and Retry-After', () async {
    await store.write('device', _device);
    await expectLater(
      transport(
        (r) async => err(
          503,
          'paused',
          message: 'الخدمة متوقفة مؤقتاً',
          extra: {'reason': 'usage_limit'},
          headers: {'retry-after': '120'},
        ),
      ).start(),
      throwsA(
        isA<RaselnaException>()
            .having((e) => e.code, 'code', 'paused')
            .having((e) => e.status, 'status', 503)
            .having((e) => e.reason, 'reason', 'usage_limit')
            .having((e) => e.message, 'message', 'الخدمة متوقفة مؤقتاً')
            .having(
              (e) => e.retryAfter,
              'retryAfter',
              const Duration(seconds: 120),
            ),
      ),
    );
    await expectLater(
      transport(
        (r) async => err(409, 'handoff_required'),
      ).reply(const TextReply('x'), idempotencyKey: 'k'),
      throwsA(
        isA<RaselnaException>().having(
          (e) => e.code,
          'code',
          'handoff_required',
        ),
      ),
    );
    await expectLater(
      transport(
        (r) async => http.Response('<html>bad gateway</html>', 502),
      ).start(),
      throwsA(
        isA<RaselnaException>().having((e) => e.code, 'code', 'http_502'),
      ),
    );
  });

  test(
    'a dropped connection is a network error (so the reply is queued)',
    () async {
      await store.write('device', _device);
      final t = transport(
        (r) async => throw http.ClientException('connection reset'),
      );
      await expectLater(
        t.reply(const TextReply('x'), idempotencyKey: 'k'),
        throwsA(isA<RaselnaNetworkException>()),
      );
    },
  );

  test(
    'resume sends the code; logout revokes the device and forgets it',
    () async {
      await store.write('device', _device);
      final t = transport(
        (r) async =>
            r.method == 'DELETE' ? http.Response('', 204) : ok('turn_slots'),
      );
      await t.resume(' 48271-95306 ');
      expect(requests.last.url.path, '/v1/conversations/resume');
      expect(jsonDecode(requests.last.body), {'code': '48271-95306'});

      await t.reset();
      expect(requests.last.method, 'DELETE');
      expect(requests.last.url.path, '/v1/devices/current');
      expect(await store.read('device'), isNull);
    },
  );

  test('a custom base URL keeps its /v1 path (fallback host)', () async {
    await store.write('device', _device);
    final t = HttpTransport(
      accessKey: _key,
      store: store,
      baseUrl: Uri.parse('https://app.raselna.com/api/v1'),
      client: MockClient((r) async {
        requests.add(r);
        return ok('turn_slots');
      }),
    );
    await t.current();
    expect(
      requests.single.url.toString(),
      'https://app.raselna.com/api/v1/conversations/current',
    );
  });

  test('setUser is not in API v1 yet', () async {
    await expectLater(
      transport((r) async => ok('config')).setUser('jwt'),
      throwsUnsupportedError,
    );
  });
}
