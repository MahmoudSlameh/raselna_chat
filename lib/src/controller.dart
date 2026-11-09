import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'models.dart';
import 'store.dart';
import 'transport.dart';

/// Who wrote a line in the conversation.
enum ChatSide { bot, customer, system }

/// Delivery of a customer message.
enum Delivery { sending, sent, queued, failed }

/// One line on screen. Bot lines come from the server; customer lines are
/// the echo of an answer (never a secret: secrets never pass the app).
class ChatEntry {
  ChatEntry({
    required this.key,
    required this.side,
    this.text,
    this.imageUrl,
    this.imageAlt,
    this.card,
    this.delivery = Delivery.sent,
    DateTime? at,
  }) : at = at ?? DateTime.now();

  final String key;
  final ChatSide side;
  final String? text;
  final String? imageUrl;
  final String? imageAlt;
  final StatusCard? card;
  Delivery delivery;
  final DateTime at;
}

enum ChatPhase { idle, loading, ready, failed }

/// Opens a handoff URL. Returns false when nothing could open it.
typedef UrlOpener = Future<bool> Function(Uri url);

/// The chat's logic without any UI: build your own widgets on it, or use
/// `RaselnaChatView`. All decisions stay on the server; this only keeps the
/// lines, the current question and the offline queue.
class RaselnaChatController extends ChangeNotifier {
  RaselnaChatController({
    required this.transport,
    RaselnaStore? store,
    this.openUrl,
    this.animateTyping = true,
    this.maxTypingDelay = const Duration(milliseconds: 1200),
    this.clock,
  }) : store = store ?? MemoryStore();

  final RaselnaTransport transport;
  final RaselnaStore store;

  /// Opens "continue in browser" links (set by `RaselnaChat`).
  UrlOpener? openUrl;

  /// Show "typing…" before bot messages. Off when the system asks for
  /// reduced motion, and in tests.
  bool animateTyping;
  final Duration maxTypingDelay;

  /// The time on new lines (fixed in golden tests).
  final DateTime Function()? clock;

  DateTime _now() => clock?.call() ?? DateTime.now();

  static const _kQueue = 'queue';

  ChatConfig? _config;
  ChatPhase _phase = ChatPhase.idle;
  Object? _error;
  final List<ChatEntry> _entries = [];
  Prompt _prompt = const NonePrompt();
  bool _typing = false;
  bool _busy = false;
  bool _offline = false;
  bool _handoffOpen = false;
  bool _disposed = false;
  int _generation = 0;
  int _seq = 0;
  final List<_Queued> _queue = [];
  Timer? _retryTimer;
  int _retryCount = 0;

  /// The business's name, logo and colours (null until loaded).
  ChatConfig? get config => _config;
  ChatPhase get phase => _phase;

  /// The error that made [phase] `failed`, or the last reply error.
  Object? get error => _error;
  List<ChatEntry> get entries => List.unmodifiable(_entries);

  /// The current question. `NonePrompt` while the bot is talking or an
  /// answer is on its way (or waiting in the offline queue).
  Prompt get prompt =>
      _busy || _queue.isNotEmpty ? const NonePrompt() : _prompt;

  /// The question as last sent, even while a reply is on its way (to keep
  /// old buttons visible but disabled).
  Prompt get lastPrompt => _prompt;
  bool get isTyping => _typing;

  /// A reply is on its way: the old question's buttons are disabled.
  bool get isBusy => _busy;
  bool get isOffline => _offline;

  /// The customer is on the web page of a rich step.
  bool get isHandoffOpen => _handoffOpen;
  int get queuedCount => _queue.length;

  /// Loads the business's look and the conversation (the current one, or a
  /// new one). Safe to call more than once.
  Future<void> load() async {
    if (_phase == ChatPhase.loading || _phase == ChatPhase.ready) return;
    _phase = ChatPhase.loading;
    _error = null;
    _notify();
    try {
      _config ??= await transport.config();
    } on Exception {
      // The chat still works with the default look.
    }
    try {
      await _restoreQueue();
      final turn = await transport.current() ?? await transport.start();
      _phase = ChatPhase.ready;
      _offline = false;
      await _apply(turn);
      unawaited(flushQueue());
    } on Exception catch (e) {
      _phase = ChatPhase.failed;
      _error = e;
      _offline = e is RaselnaNetworkException;
      _notify();
    }
  }

  /// Answers a menu question with [option].
  Future<void> choose(MenuOption option) =>
      _send(OptionReply(option.id), echo: option.label);

  /// Answers a slots question with [slot].
  Future<void> chooseSlot(SlotOption slot) =>
      _send(OptionReply(slot.id), echo: slot.label);

  /// Sends a rich-step action (add to cart, change a quantity, submit a
  /// form, pick a finder result). [echo] is the customer's line on screen.
  Future<void> act(ActionReply action, {required String echo}) =>
      _send(action, echo: echo);

  /// The rich step on screen: the current prompt, or the last one while an
  /// answer is on its way (kept visible, disabled), so sheets stay open
  /// between two adds.
  Prompt? get richPrompt => _lastRich;
  Prompt? _lastRich;

  /// Answers an input question (or types a menu option's number).
  Future<void> sendText(String text, {String? echo}) =>
      _send(TextReply(text), echo: echo ?? text);

  /// Re-sends a failed customer message with its original idempotency key.
  Future<void> retry(String entryKey) async {
    final q = _queue.where((q) => q.entryKey == entryKey).firstOrNull;
    if (q == null) return;
    _entry(entryKey)?.delivery = Delivery.sending;
    _notify();
    await flushQueue();
  }

  /// Starts a new conversation.
  Future<void> restart() async {
    _generation++;
    _queue.clear();
    await _saveQueue();
    _entries.clear();
    _prompt = const NonePrompt();
    _lastRich = null;
    _handoffOpen = false;
    await _run(transport.start);
  }

  /// Picks a paused or timed-out conversation up again.
  Future<void> continueConversation() => _run(transport.continueConversation);

  /// Takes over an older conversation by its number (when
  /// `config.canResume`).
  Future<void> resume(String code) async {
    _entries.clear();
    _prompt = const NonePrompt();
    _phase = ChatPhase.ready;
    await _run(() => transport.resume(code));
  }

  /// Asks the server for the current question again (back from the browser,
  /// app resumed). New messages are appended.
  Future<void> refresh() async {
    if (_phase != ChatPhase.ready) return load();
    try {
      final turn = await transport.current();
      _offline = false;
      if (turn == null) {
        _handoffOpen = false;
        await restart();
        return;
      }
      final wasHandoff = _prompt is HandoffPrompt;
      if (wasHandoff && turn.prompt is! HandoffPrompt) _handoffOpen = false;
      // A redisplay of the same question sends no messages: nothing doubles.
      await _apply(turn);
    } on RaselnaNetworkException {
      _offline = true;
      _notify();
    } on RaselnaException catch (e) {
      _error = e;
      _notify();
    }
  }

  /// Called when the app comes back to the foreground.
  Future<void> onResumed() async {
    if (_phase == ChatPhase.failed) return load();
    if (_phase != ChatPhase.ready) return;
    await flushQueue();
    if (_handoffOpen || _prompt is HandoffPrompt) await refresh();
  }

  /// Opens the current rich step on the secure web chat.
  Future<bool> openHandoff() async {
    try {
      final link = await transport.handoffLink();
      if (link.simulated) {
        _handoffOpen = true;
        _notify();
        await Future<void>.delayed(const Duration(milliseconds: 600));
        await refresh();
        return true;
      }
      final opener = openUrl;
      final ok = opener != null && await opener(link.url);
      _handoffOpen = ok;
      _notify();
      return ok;
    } on RaselnaNetworkException {
      _offline = true;
      _notify();
      return false;
    } on RaselnaException catch (e) {
      _error = e;
      _notify();
      return false;
    }
  }

  /// Sends every queued reply, in order. Stops at the first network error
  /// and tries again later with a growing delay.
  Future<void> flushQueue() async {
    if (_queue.isEmpty || _busy) return;
    _retryTimer?.cancel();
    _busy = true;
    _notify();
    final gen = _generation;
    try {
      while (_queue.isNotEmpty && gen == _generation) {
        final q = _queue.first;
        _entry(q.entryKey)?.delivery = Delivery.sending;
        _notify();
        final ChatTurn turn;
        try {
          turn = await transport.reply(
            q.body,
            idempotencyKey: q.idempotencyKey,
          );
        } on RaselnaNetworkException {
          _entry(q.entryKey)?.delivery = Delivery.queued;
          _offline = true;
          _scheduleRetry();
          return;
        } on RaselnaException catch (e) {
          // 5xx, 429 and `busy` may pass later: keep the reply (same key).
          // `busy` and 429 retry on their own after the server's delay;
          // 5xx waits for a tap. Anything else is final for this answer.
          final busy = e.code == 'busy' || e.status == 429;
          final transient = busy || (e.status ?? 0) >= 500;
          if (!transient) {
            _queue.removeAt(0);
            await _saveQueue();
          }
          _onReplyError(q.entryKey, e);
          if (busy) {
            _entry(q.entryKey)?.delivery = Delivery.queued;
            _retryTimer?.cancel();
            _retryTimer = Timer(
              e.retryAfter ?? const Duration(seconds: 2),
              () => unawaited(flushQueue()),
            );
          }
          return;
        }
        _queue.removeAt(0);
        await _saveQueue();
        _offline = false;
        _retryCount = 0;
        _entry(q.entryKey)?.delivery = Delivery.sent;
        await _apply(turn);
      }
    } finally {
      _busy = false;
      _notify();
    }
  }

  /// Identified mode (stub for now; see README).
  Future<void> setUser(String userJwt) => transport.setUser(userJwt);

  /// Forgets the conversation and the queue on this device.
  Future<void> reset() async {
    _generation++;
    _queue.clear();
    await _saveQueue();
    await transport.reset();
    _entries.clear();
    _prompt = const NonePrompt();
    _lastRich = null;
    _phase = ChatPhase.idle;
    _handoffOpen = false;
    _notify();
  }

  // --- Internals ----------------------------------------------------------

  Future<void> _send(ReplyBody body, {required String echo}) async {
    if (_busy || _phase != ChatPhase.ready) return;
    final key = 'c${++_seq}';
    _entries.add(
      ChatEntry(
        key: key,
        side: ChatSide.customer,
        text: echo,
        delivery: Delivery.sending,
        at: _now(),
      ),
    );
    _queue.add(_Queued(key, _newIdempotencyKey(), body, echo));
    await _saveQueue();
    await flushQueue();
  }

  void _onReplyError(String entryKey, RaselnaException e) {
    _error = e;
    _entry(entryKey)?.delivery = Delivery.failed;
    if (e.status == 410 || e.code == 'session_ended') {
      // The conversation is over: the queue is meaningless now.
      _queue.clear();
      unawaited(_saveQueue());
      _prompt = const EndPrompt();
    } else if (e.code == 'handoff_required') {
      // The step must be answered in the browser: fetch it again.
      unawaited(refresh());
    } else if (e.status != null &&
        e.status! < 500 &&
        e.code != 'busy' &&
        e.status != 429) {
      // The server's own short sentence (Arabic), safe to show.
      final m = e.message;
      if (m != null && m.isNotEmpty) {
        _entries.add(
          ChatEntry(
            key: 'e${++_seq}',
            side: ChatSide.system,
            text: m,
            at: _now(),
          ),
        );
      }
    }
    _notify();
  }

  /// Whether a failed customer line can be sent again.
  bool canRetry(String entryKey) => _queue.any((q) => q.entryKey == entryKey);

  void _scheduleRetry() {
    _retryTimer?.cancel();
    final seconds = min(60, 5 * (1 << min(_retryCount, 4)));
    _retryCount++;
    _retryTimer = Timer(
      Duration(seconds: seconds),
      () => unawaited(flushQueue()),
    );
  }

  Future<void> _run(Future<ChatTurn> Function() call) async {
    if (_busy) return;
    _busy = true;
    _notify();
    try {
      final turn = await call();
      _phase = ChatPhase.ready;
      _offline = false;
      await _apply(turn);
    } on RaselnaNetworkException catch (e) {
      _offline = true;
      _error = e;
    } on RaselnaException catch (e) {
      _error = e;
    } finally {
      _busy = false;
      _notify();
    }
  }

  /// Reveals the bot's messages one by one ("typing…" first), then the
  /// question.
  Future<void> _apply(ChatTurn turn) async {
    final gen = _generation;
    _prompt = const NonePrompt();
    for (final m in turn.messages) {
      final delay = Duration(
        milliseconds: min(m.typingMs, maxTypingDelay.inMilliseconds),
      );
      if (animateTyping && delay > Duration.zero) {
        _typing = true;
        _notify();
        await Future<void>.delayed(delay);
        if (gen != _generation || _disposed) return;
      }
      _typing = false;
      _entries.add(_toEntry(m));
      _notify();
    }
    _typing = false;
    _prompt = turn.prompt;
    _lastRich = turn.prompt.isRichNative ? turn.prompt : null;
    _notify();
  }

  ChatEntry _toEntry(ChatMessage m) {
    final key = 'b${++_seq}';
    return switch (m) {
      TextMessage(:final text, :final card) => ChatEntry(
        key: key,
        side: ChatSide.bot,
        text: text,
        card: card,
        at: _now(),
      ),
      ImageMessage(:final url, :final alt, :final caption) => ChatEntry(
        key: key,
        side: ChatSide.bot,
        imageUrl: url,
        imageAlt: alt,
        text: caption,
        at: _now(),
      ),
      StatusMessage(:final text) => ChatEntry(
        key: key,
        side: ChatSide.system,
        text: text,
        at: _now(),
      ),
    };
  }

  ChatEntry? _entry(String key) =>
      _entries.where((e) => e.key == key).firstOrNull;

  Future<void> _saveQueue() => store.write(
    _kQueue,
    _queue.isEmpty ? null : jsonEncode([for (final q in _queue) q.toJson()]),
  );

  Future<void> _restoreQueue() async {
    if (_queue.isNotEmpty) return;
    final raw = await store.read(_kQueue);
    if (raw == null) return;
    try {
      final list = jsonDecode(raw);
      if (list is! List) return;
      for (final j in list.whereType<Map<String, dynamic>>()) {
        final q = _Queued.fromJson(j);
        if (q == null) continue;
        _queue.add(q);
        _entries.add(
          ChatEntry(
            key: q.entryKey,
            side: ChatSide.customer,
            text: q.echo,
            delivery: Delivery.queued,
            at: _now(),
          ),
        );
        _seq++;
      }
    } on FormatException {
      await store.write(_kQueue, null);
    }
  }

  static final _random = Random.secure();

  static String _newIdempotencyKey() {
    final b = StringBuffer();
    for (var i = 0; i < 16; i++) {
      b.write(_random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return b.toString();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _retryTimer?.cancel();
    super.dispose();
  }
}

/// A reply waiting to be sent. Only option ids and typed answers: secret
/// steps never reach the app, so nothing sensitive is ever written down.
class _Queued {
  _Queued(this.entryKey, this.idempotencyKey, this.body, this.echo);

  final String entryKey;
  final String idempotencyKey;
  final ReplyBody body;
  final String echo;

  Map<String, dynamic> toJson() => {
    'k': entryKey,
    'i': idempotencyKey,
    'b': body.toJson(),
    'e': echo,
  };

  static _Queued? fromJson(Map<String, dynamic> j) {
    final k = j['k'];
    final i = j['i'];
    final b = j['b'];
    final e = j['e'];
    if (k is! String || i is! String || b is! Map || e is! String) return null;
    final ReplyBody body;
    final action = b['action'];
    if (b['option_id'] is String) {
      body = OptionReply(b['option_id'] as String);
    } else if (b['text'] is String) {
      body = TextReply(b['text'] as String);
    } else if (action is Map && action['type'] is String) {
      final values = action['values'];
      body = ActionReply(
        action['type'] as String,
        product:
            action['product'] is String ? action['product'] as String : null,
        line: action['line'] is String ? action['line'] as String : null,
        qty: action['qty'] is num ? action['qty'] as num : null,
        options:
            action['options'] is List
                ? [
                  for (final o
                      in (action['options'] as List).whereType<String>())
                    o,
                ]
                : null,
        values:
            values is Map
                ? {
                  for (final e in values.entries)
                    if (e.key is String && e.value is String)
                      e.key as String: e.value as String,
                }
                : null,
      );
    } else {
      return null;
    }
    return _Queued('r$k', i, body, e);
  }
}
