import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'controller.dart';
import 'http_transport.dart';
import 'store.dart';
import 'strings.dart';
import 'theme.dart';
import 'transport.dart';
import 'widgets/chat_view.dart';

/// The SDK's entry point.
///
/// ```dart
/// await RaselnaChat.init(accessKey: 'rpk_live_…');
/// RaselnaChat.open(context);
/// ```
abstract final class RaselnaChat {
  static RaselnaChatController? _controller;
  static String _locale = 'ar';
  static RaselnaStrings? _strings;
  static RaselnaChatTheme? _theme;
  static ThemeMode _themeMode = ThemeMode.system;

  /// Sets the SDK up. Call once, e.g. in `main()`.
  ///
  /// [accessKey] is the app's PUBLISHABLE key (`rpk_live_…` or `rpk_test_…`)
  /// from the Raselna dashboard. It is public by design: anyone can read it
  /// from your app. Never put a secret in a mobile app.
  ///
  /// [appId] is your Android package name / iOS bundle id, sent as
  /// `X-Raselna-App` (required when the key is limited to listed apps).
  ///
  /// [transport] replaces the network (e.g. `MockTransport()` for demos and
  /// tests). [store] replaces where the device credential and the offline
  /// queue are kept (default: Keychain / Keystore).
  static Future<void> init({
    required String accessKey,
    Uri? baseUrl,
    String locale = 'ar',
    String? flow,
    String? appId,
    String? source,
    String? appVersion,
    RaselnaTransport? transport,
    RaselnaStore? store,
    RaselnaChatTheme? theme,
    ThemeMode themeMode = ThemeMode.system,
    RaselnaStrings? strings,
    http.Client? httpClient,
  }) async {
    if (transport == null) _checkKey(accessKey);
    if (baseUrl != null && baseUrl.scheme != 'https' && !_isLocal(baseUrl)) {
      throw ArgumentError.value(baseUrl.toString(), 'baseUrl', 'must be https');
    }
    final s = store ?? SecureStore();
    _controller?.dispose();
    _locale = locale;
    _strings = strings;
    _theme = theme;
    _themeMode = themeMode;
    _controller = RaselnaChatController(
      transport:
          transport ??
          HttpTransport(
            accessKey: accessKey,
            baseUrl: baseUrl,
            store: s,
            flow: flow,
            appId: appId,
            source: source,
            appVersion: appVersion,
            locale: locale,
            client: httpClient,
          ),
      store: s,
      openUrl: _openInBrowser,
    );
  }

  static bool get isInitialized => _controller != null;

  /// The controller behind the default views (headless use, tests).
  static RaselnaChatController get controller {
    final c = _controller;
    if (c == null) {
      throw StateError(
        'Call RaselnaChat.init(accessKey: …) before using the chat.',
      );
    }
    return c;
  }

  static String get locale => _locale;
  static RaselnaChatTheme? get theme => _theme;
  static ThemeMode get themeMode => _themeMode;

  /// The strings for [locale]: yours if you passed any, else the built-in.
  static RaselnaStrings stringsFor(String locale) =>
      _strings ?? RaselnaStrings.forLocale(locale);

  /// Opens the chat full screen, or as a tall bottom sheet with
  /// [asBottomSheet].
  static Future<void> open(BuildContext context, {bool asBottomSheet = false}) {
    if (asBottomSheet) {
      return showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder:
            (context) => FractionallySizedBox(
              heightFactor: 0.92,
              child: RaselnaChatView(
                onClose: () => Navigator.of(context).pop(),
              ),
            ),
      );
    }
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder:
            (context) => Scaffold(
              body: RaselnaChatView(onClose: () => Navigator.of(context).pop()),
            ),
      ),
    );
  }

  /// Identified mode. NOT in the chat API v1 yet: throws
  /// `UnsupportedError` with the HTTP transport. When it lands, [userJwt]
  /// will be signed by YOUR server; the signing secret never goes in the app.
  static Future<void> setUser(String userJwt) => controller.setUser(userJwt);

  /// Logs this install out: revokes the device credential
  /// (`DELETE /devices/current`) and forgets the queue.
  static Future<void> logout() => controller.reset();

  static Future<bool> _openInBrowser(Uri url) async {
    if (url.scheme != 'https') return false;
    try {
      // Custom Tabs on Android, SFSafariViewController on iOS: the page
      // runs in the system browser engine, not in a WebView we control.
      return await launchUrl(url, mode: LaunchMode.inAppBrowserView);
    } on Exception {
      return launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  static void _checkKey(String key) {
    if (key.startsWith('rpk_live_') || key.startsWith('rpk_test_')) return;
    final looksSecret = RegExp(r'^(rsk|ids|sk)_').hasMatch(key);
    throw ArgumentError.value(
      looksSecret ? '<redacted>' : key,
      'accessKey',
      looksSecret
          ? 'this looks like a SECRET key. Never ship secrets in an app; '
              'use the publishable key (rpk_live_… / rpk_test_…).'
          : 'expected a publishable key (rpk_live_… or rpk_test_…)',
    );
  }

  static bool _isLocal(Uri u) =>
      u.host == 'localhost' || u.host == '127.0.0.1' || u.host == '10.0.2.2';
}
