import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raselna_chat/raselna_chat.dart';

/// A transport the test scripts: [onStart] is the first turn, [onReply]
/// answers each reply. Records every call.
class FakeTransport extends RaselnaTransport {
  FakeTransport({
    required this.onStart,
    ChatTurn Function(ReplyBody body)? onReply,
    this.configValue = const ChatConfig(
      botName: 'فرن الياسمين',
      palette: TenantPalette(primary: Color(0xFFB4441A)),
    ),
  }) : onReply =
           onReply ??
           ((_) => const ChatTurn(messages: [], prompt: EndPrompt()));

  final ChatTurn Function() onStart;
  final ChatTurn Function(ReplyBody body) onReply;
  final ChatConfig configValue;

  final replies = <ReplyBody>[];
  final idempotencyKeys = <String>[];
  int starts = 0;
  int continues = 0;
  int handoffs = 0;
  bool offline = false;
  RaselnaException? failWith;
  ChatTurn? currentTurn;

  @override
  Future<ChatConfig> config() async => configValue;

  @override
  Future<ChatTurn?> current() async => currentTurn;

  @override
  Future<ChatTurn> start() async {
    starts++;
    return onStart();
  }

  @override
  Future<ChatTurn> reply(
    ReplyBody body, {
    required String idempotencyKey,
  }) async {
    idempotencyKeys.add(idempotencyKey);
    if (offline) throw const RaselnaNetworkException('test');
    final fail = failWith;
    if (fail != null) throw fail;
    replies.add(body);
    return onReply(body);
  }

  @override
  Future<ChatTurn> continueConversation() async {
    continues++;
    return onStart();
  }

  @override
  Future<HandoffLink> handoffLink() async {
    handoffs++;
    return HandoffLink(url: Uri.parse('https://bakery.raselna.com/#h=abc'));
  }

  @override
  Future<void> reset() async {}
}

ChatTurn turn(Prompt prompt, [List<String> texts = const ['أهلاً فيك 👋']]) =>
    ChatTurn(
      messages: [
        for (var i = 0; i < texts.length; i++)
          TextMessage(id: 'm$i', text: texts[i]),
      ],
      prompt: prompt,
    );

RaselnaChatController controllerFor(
  RaselnaTransport t, {
  RaselnaStore? store,
}) => RaselnaChatController(
  transport: t,
  store: store,
  animateTyping: false,
  clock: () => DateTime(2026, 11, 8, 10, 42),
);

/// Pumps the chat in an app and waits for the first turn.
Future<RaselnaChatController> pumpChat(
  WidgetTester tester,
  RaselnaTransport transport, {
  ThemeMode themeMode = ThemeMode.light,
  String locale = 'ar',
  UrlOpener? openUrl,
}) async {
  final ctl = controllerFor(transport)..openUrl = openUrl;
  addTearDown(ctl.dispose);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: RaselnaChatView(
          controller: ctl,
          themeMode: themeMode,
          locale: locale,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ctl;
}

/// Real glyphs in goldens: the bundled Tajawal and, when the Flutter SDK is
/// found, Material Icons.
Future<void> loadTestFonts() async {
  Future<ByteData> bytes(String path) async =>
      ByteData.view((await File(path).readAsBytes()).buffer);

  final tajawal = FontLoader('packages/raselna_chat/Tajawal');
  for (final w in ['Regular', 'Medium', 'Bold']) {
    tajawal.addFont(bytes('fonts/Tajawal-$w.ttf'));
  }
  await tajawal.load();

  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final icons = File(
      '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (icons.existsSync()) {
      await (FontLoader('MaterialIcons')..addFont(bytes(icons.path))).load();
    }
  }
}
