import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:http/http.dart' as http;

import 'models.dart';
import 'store.dart';
import 'transport.dart';
import 'version.dart';

/// The Raselna public chat API v1 over HTTPS (`public/openapi/chat-v1.yaml`).
///
/// - `X-Raselna-Key`: the publishable key. Public by design; it only names
///   the business and the app.
/// - `X-Raselna-Device`: `{device_id}.{device_secret}` from `POST /devices`,
///   registered once per install. The secret is kept in [store] (secure
///   storage by default) and never logged.
/// - There is no conversation token: the device has one current
///   conversation, so a browser handoff never breaks the app's binding.
class HttpTransport extends RaselnaTransport {
  HttpTransport({
    required this.accessKey,
    Uri? baseUrl,
    required this.store,
    this.appId,
    this.flow,
    this.source,
    this.locale = 'ar',
    this.appVersion,
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
  }) : baseUrl = _withSlash(baseUrl ?? defaultBaseUrl),
       _client = client ?? http.Client();

  /// Primary host. `https://app.raselna.com/api/v1/` is the documented
  /// fallback for networks that block the `api.` name.
  static final defaultBaseUrl = Uri.parse('https://api.raselna.com/v1/');

  final String accessKey;
  final Uri baseUrl;
  final RaselnaStore store;

  /// Android package name / iOS bundle id, sent as `X-Raselna-App`.
  /// Required when the key lists allowed apps.
  final String? appId;

  /// A published flow's slug; null = the business's default flow.
  final String? flow;

  /// Where the customer came from (a screen, a campaign), for statistics.
  final String? source;
  final String locale;
  final String? appVersion;
  final Duration timeout;
  final http.Client _client;

  static const _kDevice = 'device';

  String? _device;
  bool _loaded = false;
  String? _etag;
  ChatConfig? _config;

  @override
  Future<ChatConfig> config() async {
    final res = await _send(
      'GET',
      'config',
      device: false,
      headers: {if (_etag != null && _config != null) 'If-None-Match': _etag!},
    );
    if (res.status == 304 && _config != null) return _config!;
    _etag = res.etag;
    return _config = ChatConfig.fromJson(res.json);
  }

  @override
  Future<ChatTurn?> current() async {
    try {
      return ChatTurn.fromJson(
        (await _send('GET', 'conversations/current')).json,
      );
    } on RaselnaException catch (e) {
      // No conversation yet, or it is over: the caller starts a new one.
      if (e.code == 'conversation_not_found' || e.status == 410) return null;
      rethrow;
    }
  }

  @override
  Future<ChatTurn> start() async => ChatTurn.fromJson(
    (await _send(
      'POST',
      'conversations',
      body: {if (flow != null) 'flow': flow, if (source != null) 'src': source},
    )).json,
  );

  @override
  Future<ChatTurn> resume(String code) async => ChatTurn.fromJson(
    (await _send(
      'POST',
      'conversations/resume',
      body: {'code': code.trim()},
    )).json,
  );

  @override
  Future<ChatTurn> reply(
    ReplyBody body, {
    required String idempotencyKey,
  }) async => ChatTurn.fromJson(
    (await _send(
      'POST',
      'conversations/current/reply',
      body: body.toJson(),
      headers: {'Idempotency-Key': idempotencyKey},
    )).json,
  );

  @override
  Future<ChatTurn> continueConversation() async => ChatTurn.fromJson(
    (await _send('POST', 'conversations/current/continue')).json,
  );

  @override
  Future<HandoffLink> handoffLink() async {
    final json =
        (await _send('POST', 'conversations/current/handoff-link')).json;
    final url = Uri.tryParse('${json['url'] ?? ''}');
    if (url == null || url.scheme != 'https' || url.host.isEmpty) {
      throw const RaselnaException('invalid_handoff');
    }
    return HandoffLink(
      url: url,
      expiresAt: DateTime.tryParse('${json['expires_at'] ?? ''}'),
    );
  }

  @override
  Future<void> setUser(String userJwt) async {
    throw UnsupportedError('Identified users are not in the chat API v1 yet.');
  }

  /// Logs this install out: revokes the device credential on the server
  /// (best effort, works offline too) and forgets it here.
  @override
  Future<void> reset() async {
    await _load();
    if (_device != null) {
      try {
        await _send('DELETE', 'devices/current', register: false);
      } on Exception {
        // Logging out locally must work offline too.
      }
    }
    _device = null;
    await store.write(_kDevice, null);
  }

  Future<void> _load() async {
    if (_loaded) return;
    _device = await store.read(_kDevice);
    _loaded = true;
  }

  Future<String> _ensureDevice() async {
    await _load();
    final known = _device;
    if (known != null) return known;
    final res = await _send(
      'POST',
      'devices',
      device: false,
      body: {
        'platform': _platform(),
        'sdk_version': raselnaSdkVersion,
        if (appVersion != null) 'app_version': appVersion,
      },
    );
    final id = res.json['device_id'];
    final secret = res.json['device_secret'];
    if (id is! String || secret is! String || id.isEmpty || secret.isEmpty) {
      throw const RaselnaException('invalid_device');
    }
    final device = '$id.$secret';
    _device = device;
    await store.write(_kDevice, device);
    return device;
  }

  Future<_Response> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
    bool device = true,
    bool register = true,
  }) async {
    final request = http.Request(method, baseUrl.resolve(path));
    request.headers.addAll({
      'Accept': 'application/json',
      'Accept-Language': locale,
      'X-Raselna-Key': accessKey,
      'X-Raselna-SDK': 'flutter/$raselnaSdkVersion',
      'X-Raselna-Capabilities': raselnaCapabilities.join(','),
      if (appId != null) 'X-Raselna-App': appId!,
      ...headers,
    });
    if (device) request.headers['X-Raselna-Device'] = await _ensureDevice();
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _client.send(request).timeout(timeout),
      ).timeout(timeout);
    } on TimeoutException catch (e) {
      throw RaselnaNetworkException(e);
    } on http.ClientException catch (e) {
      throw RaselnaNetworkException(e);
    } on Exception catch (e) {
      // SocketException, HandshakeException…: the server never answered.
      throw RaselnaNetworkException(e);
    }

    Object? decoded;
    try {
      decoded =
          response.bodyBytes.isEmpty
              ? null
              : jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      decoded = null;
    }
    final json =
        decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    final status = response.statusCode;

    if ((status >= 200 && status < 300) || status == 304) {
      return _Response(status, json, response.headers['etag']);
    }

    final code =
        json['error'] is String ? json['error'] as String : 'http_$status';

    // The credential was revoked or never existed: register once, retry once.
    if (code == 'device_not_found' && device) {
      _device = null;
      await store.write(_kDevice, null);
      if (register) {
        return _send(
          method,
          path,
          body: body,
          headers: headers,
          register: false,
        );
      }
    }

    throw RaselnaException(
      code,
      status: status,
      message: json['message'] is String ? json['message'] as String : null,
      reason: json['reason'] is String ? json['reason'] as String : null,
      retryAfter: _retryAfter(response.headers['retry-after']),
    );
  }

  static Duration? _retryAfter(String? header) {
    final s = int.tryParse(header?.trim() ?? '');
    return s == null || s < 0
        ? null
        : Duration(seconds: s.clamp(1, 3600).toInt());
  }

  static String _platform() {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'ios',
      // The API knows android, ios and web only.
      _ => 'android',
    };
  }

  static Uri _withSlash(Uri u) =>
      u.path.endsWith('/') ? u : u.replace(path: '${u.path}/');
}

class _Response {
  const _Response(this.status, this.json, this.etag);

  final int status;
  final Map<String, dynamic> json;
  final String? etag;
}
