import 'models.dart';

/// How the SDK talks to a conversation. [HttpTransport] is the real API;
/// [MockTransport] plays scripted demo conversations with no network.
///
/// Implementations throw [RaselnaNetworkException] when the request did not
/// reach the server (so the reply is queued) and [RaselnaException] for API
/// errors.
abstract class RaselnaTransport {
  /// The business's name, logo and colours.
  Future<ChatConfig> config();

  /// The current question again (app reopened, back from the browser), or
  /// null when there is no conversation yet.
  Future<ChatTurn?> current();

  /// Starts a new conversation.
  Future<ChatTurn> start();

  /// Answers the current question. [idempotencyKey] is fixed per answer, so
  /// a retry after a lost response is never applied twice.
  Future<ChatTurn> reply(ReplyBody body, {required String idempotencyKey});

  /// Picks a paused or timed-out conversation up again.
  Future<ChatTurn> continueConversation();

  /// Takes over an older conversation by its number (the `code` of a
  /// paused prompt). Only when `ChatConfig.canResume`.
  Future<ChatTurn> resume(String code) async =>
      throw const RaselnaException('not_supported');

  /// A one-time link that opens the current rich step on the web chat.
  Future<HandoffLink> handoffLink();

  /// Identified mode (later): exchanges the app's user JWT, signed by the
  /// business's own server, for a user session. Optional for transports.
  Future<void> setUser(String userJwt) async {}

  /// Forgets the conversation (and the identified user) on this device.
  Future<void> reset();
}
