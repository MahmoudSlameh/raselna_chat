/// Drop-in, Arabic-first chat with a Raselna business bot.
///
/// ```dart
/// await RaselnaChat.init(accessKey: 'rpk_live_…');
/// // A full screen or bottom sheet:
/// RaselnaChat.open(context);
/// // Or a widget anywhere:
/// const RaselnaChatView();
/// ```
library;

export 'src/controller.dart'
    show
        ChatEntry,
        ChatPhase,
        ChatSide,
        Delivery,
        RaselnaChatController,
        UrlOpener;
export 'src/http_transport.dart' show HttpTransport;
export 'src/mock_transport.dart' show MockScenario, MockTransport;
export 'src/models.dart';
export 'src/raselna_chat.dart' show RaselnaChat;
export 'src/store.dart';
export 'src/strings.dart';
export 'src/theme.dart'
    show
        RaselnaChatColors,
        RaselnaChatColorsScope,
        RaselnaChatTheme,
        contrastRatio,
        derivePalette;
export 'src/transport.dart';
export 'src/validators.dart' show normalizeDigits, validateAnswer;
export 'src/version.dart';
export 'src/widgets/chat_view.dart' show RaselnaChatView;
