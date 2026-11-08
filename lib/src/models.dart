// The chat API contract as the SDK sees it. The server decides everything;
// the SDK renders what it is sent. There are no node ids, variable names or
// graph internals here, and option ids are opaque per-question tokens.

import 'dart:ui' show Color;

/// One answer from the server: what the bot says, then what it asks.
class ChatTurn {
  const ChatTurn({
    required this.messages,
    required this.prompt,
    this.conversation,
  });

  factory ChatTurn.fromJson(Map<String, dynamic> json) {
    final raw = json['messages'];
    var prompt = Prompt.fromJson(_map(json['prompt']));
    // `handoff.required` wins over the prompt: the step is answered in the
    // browser whatever its kind (a secret question, a rich step).
    final handoff = _map(json['handoff']);
    if (handoff['required'] == true && prompt is! HandoffPrompt) {
      prompt = HandoffPrompt(
        kind: prompt.kind,
        reason:
            handoff['reason'] == 'secret'
                ? HandoffReason.secret
                : HandoffReason.unknown,
      );
    } else if (handoff['reason'] == 'secret' &&
        prompt is HandoffPrompt &&
        prompt.reason != HandoffReason.secret) {
      prompt = HandoffPrompt(kind: prompt.kind, reason: HandoffReason.secret);
    }
    final conv = _map(json['conversation']);
    return ChatTurn(
      messages:
          raw is List
              ? raw
                  .whereType<Map<String, dynamic>>()
                  .map(ChatMessage.fromJson)
                  .whereType<ChatMessage>()
                  .toList(growable: false)
              : const [],
      prompt: prompt,
      conversation: conv.isEmpty ? null : ConversationInfo.fromJson(conv),
    );
  }

  final List<ChatMessage> messages;
  final Prompt prompt;

  /// The conversation's public id and status (null from the mock).
  final ConversationInfo? conversation;
}

enum ConversationStatus { active, paused, completed, ended, unknown }

/// Public facts about the current conversation.
class ConversationInfo {
  const ConversationInfo({
    required this.id,
    this.status = ConversationStatus.active,
    this.expiresAt,
    this.test = false,
  });

  factory ConversationInfo.fromJson(Map<String, dynamic> json) =>
      ConversationInfo(
        id: _str(json['id']) ?? '',
        status: switch (json['status']) {
          'active' => ConversationStatus.active,
          'paused' => ConversationStatus.paused,
          'completed' => ConversationStatus.completed,
          'ended' => ConversationStatus.ended,
          _ => ConversationStatus.unknown,
        },
        expiresAt: DateTime.tryParse('${json['expires_at'] ?? ''}'),
        test: json['test'] == true,
      );

  /// Public id (support, push payloads). Not a secret.
  final String id;
  final ConversationStatus status;
  final DateTime? expiresAt;

  /// Started with a `rpk_test_` key: not billed, not counted.
  final bool test;
}

/// "Step n of m" of a linear form.
class StepProgress {
  const StepProgress(this.step, this.total);

  static StepProgress? fromJson(Object? json) {
    if (json is! Map) return null;
    final step = json['step'];
    final total = json['total'];
    if (step is! int || total is! int || total <= 0) return null;
    return StepProgress(step, total);
  }

  final int step;
  final int total;
}

enum StatusTone { success, warning, danger, neutral }

/// A status card hint on a bot text, e.g. an order's current state.
class StatusCard {
  const StatusCard({
    required this.title,
    required this.status,
    this.tone = StatusTone.neutral,
  });

  static StatusCard? fromJson(Object? json) {
    if (json is! Map) return null;
    final title = json['title'];
    final status = json['status'];
    if (title is! String || status is! String) return null;
    return StatusCard(
      title: title,
      status: status,
      tone: switch (json['tone']) {
        'success' => StatusTone.success,
        'warning' => StatusTone.warning,
        'danger' => StatusTone.danger,
        _ => StatusTone.neutral,
      },
    );
  }

  final String title;
  final String status;
  final StatusTone tone;
}

/// A bot message. Unknown message types are dropped (forward compatible).
sealed class ChatMessage {
  const ChatMessage({required this.id, this.typingMs = 0});

  final String id;

  /// How long the "typing…" indicator shows before this message.
  final int typingMs;

  static ChatMessage? fromJson(Map<String, dynamic> json) {
    final id = '${json['id'] ?? ''}';
    final typing = json['typing_ms'] is int ? json['typing_ms'] as int : 0;
    switch (json['type']) {
      case 'text':
        final text = json['text'];
        if (text is! String) return null;
        return TextMessage(
          id: id,
          text: text,
          typingMs: typing,
          card: StatusCard.fromJson(json['card']),
        );
      case 'image':
        final url = json['url'];
        if (url is! String || !_isHttpUrl(url)) return null;
        return ImageMessage(
          id: id,
          url: url,
          alt: json['alt'] is String ? json['alt'] as String : null,
          caption: json['text'] is String ? json['text'] as String : null,
          typingMs: typing,
        );
      case 'status':
        final text = json['text'];
        if (text is! String) return null;
        return StatusMessage(id: id, text: text);
      default:
        return null;
    }
  }
}

class TextMessage extends ChatMessage {
  const TextMessage({
    required super.id,
    required this.text,
    super.typingMs,
    this.card,
  });

  final String text;
  final StatusCard? card;
}

class ImageMessage extends ChatMessage {
  const ImageMessage({
    required super.id,
    required this.url,
    this.alt,
    this.caption,
    super.typingMs,
  });

  final String url;
  final String? alt;
  final String? caption;
}

/// A centred system line ("The conversation was transferred…").
class StatusMessage extends ChatMessage {
  const StatusMessage({required super.id, required this.text});

  final String text;
}

class MenuOption {
  const MenuOption({
    required this.id,
    required this.label,
    required this.index,
  });

  final String id;
  final String label;

  /// 1-based number the customer can also type.
  final int index;
}

enum MenuDisplay { buttons, list }

/// What the bot asks now.
sealed class Prompt {
  const Prompt();

  /// The raw `kind` string from the server.
  String get kind;

  factory Prompt.fromJson(Map<String, dynamic> json) {
    final kind = json['kind'];
    switch (kind) {
      case 'menu':
        final options = <MenuOption>[];
        final raw = json['options'];
        if (raw is List) {
          var n = 0;
          for (final o in raw.whereType<Map>()) {
            n++;
            final id = o['id'];
            final label = o['label'];
            if (id is String && label is String) {
              options.add(
                MenuOption(
                  id: id,
                  label: label,
                  index: o['index'] is int ? o['index'] as int : n,
                ),
              );
            }
          }
        }
        return MenuPrompt(
          options: options,
          display:
              json['display'] == 'list' || options.length > 3
                  ? MenuDisplay.list
                  : MenuDisplay.buttons,
          listButtonText: _str(json['list_button_text']),
        );
      case 'input':
        final type = InputKind.parse(_str(json['input_type']));
        // Secret answers never go through the app: the step continues on
        // the secure web page instead (see HandoffPrompt).
        if (type == InputKind.secret) {
          return const HandoffPrompt(
            kind: 'input',
            reason: HandoffReason.secret,
          );
        }
        return InputPrompt(
          inputKind: type,
          placeholder: _str(json['placeholder']),
          progress: StepProgress.fromJson(json['progress']),
        );
      case 'slots':
        return SlotsPrompt.fromJson(json);
      case 'end':
        return EndPrompt(showRestart: json['show_restart'] != false);
      case 'paused':
        return PausedPrompt(code: _str(json['code']) ?? '');
      case 'none':
      case null:
        return const NonePrompt();
      case 'product_list':
        return HandoffPrompt(
          kind: 'product_list',
          reason: HandoffReason.catalog,
          label: _str(json['done_label']),
          count:
              json['products'] is List
                  ? (json['products'] as List).length
                  : null,
        );
      case 'cart':
        return HandoffPrompt(
          kind: 'cart',
          reason: HandoffReason.cart,
          label: _str(json['confirm_label']),
        );
      case 'form':
        return HandoffPrompt(
          kind: 'form',
          reason: HandoffReason.form,
          label: _str(json['open_label']) ?? _str(json['title']),
        );
      default:
        // A step this SDK version does not know yet: never break, hand the
        // step over to the web chat.
        return HandoffPrompt(kind: '$kind', reason: HandoffReason.unknown);
    }
  }
}

class MenuPrompt extends Prompt {
  const MenuPrompt({
    required this.options,
    this.display = MenuDisplay.buttons,
    this.listButtonText,
  });

  final List<MenuOption> options;
  final MenuDisplay display;
  final String? listButtonText;

  @override
  String get kind => 'menu';
}

enum InputKind {
  text,
  number,
  phone,
  email,
  date,
  secret;

  static InputKind parse(String? raw) => switch (raw) {
    'number' || 'numeric' || 'integer' || 'decimal' => InputKind.number,
    'phone' || 'tel' || 'mobile' => InputKind.phone,
    'email' => InputKind.email,
    'date' => InputKind.date,
    'password' || 'secret' => InputKind.secret,
    _ => InputKind.text,
  };
}

class InputPrompt extends Prompt {
  const InputPrompt({
    this.inputKind = InputKind.text,
    this.placeholder,
    this.progress,
  });

  final InputKind inputKind;
  final String? placeholder;
  final StepProgress? progress;

  @override
  String get kind => 'input';
}

class SlotOption {
  const SlotOption({required this.id, required this.label});

  final String id;
  final String label;
}

class SlotGroup {
  const SlotGroup({this.label, required this.options});

  final String? label;
  final List<SlotOption> options;
}

/// Free days or times (booking). Answered with a plain option reply.
class SlotsPrompt extends Prompt {
  const SlotsPrompt({
    this.title,
    this.emptyText,
    this.groups = const [],
    this.actions = const [],
  });

  factory SlotsPrompt.fromJson(Map<String, dynamic> json) {
    List<SlotOption> options(Object? raw) =>
        raw is List
            ? [
              for (final o in raw.whereType<Map>())
                if (o['id'] is String && o['label'] is String)
                  SlotOption(
                    id: o['id'] as String,
                    label: o['label'] as String,
                  ),
            ]
            : const [];

    final groups = json['groups'];
    return SlotsPrompt(
      title: _str(json['title']),
      emptyText: _str(json['empty_text']),
      groups:
          groups is List
              ? [
                for (final g in groups.whereType<Map>())
                  SlotGroup(
                    label: _str(g['label']),
                    options: options(g['options']),
                  ),
              ]
              : const [],
      actions: options(json['actions']),
    );
  }

  final String? title;
  final String? emptyText;
  final List<SlotGroup> groups;
  final List<SlotOption> actions;

  @override
  String get kind => 'slots';
}

class EndPrompt extends Prompt {
  const EndPrompt({this.showRestart = true});

  final bool showRestart;

  @override
  String get kind => 'end';
}

/// The conversation waits; [code] lets the customer come back to it.
class PausedPrompt extends Prompt {
  const PausedPrompt({required this.code});

  final String code;

  @override
  String get kind => 'paused';
}

/// Nothing to answer (the bot is still talking).
class NonePrompt extends Prompt {
  const NonePrompt();

  @override
  String get kind => 'none';
}

enum HandoffReason { catalog, cart, form, secret, unknown }

/// A rich or sensitive step that continues on the business's secure web
/// chat ("continue in browser"), then the app picks the conversation up.
class HandoffPrompt extends Prompt {
  const HandoffPrompt({
    required this.kind,
    required this.reason,
    this.label,
    this.count,
  });

  @override
  final String kind;
  final HandoffReason reason;

  /// The server's own button text, when it sends one.
  final String? label;

  /// How many products a catalog holds, for the card's subtitle.
  final int? count;
}

/// The customer's answer.
sealed class ReplyBody {
  const ReplyBody();

  Map<String, dynamic> toJson();
}

class OptionReply extends ReplyBody {
  const OptionReply(this.optionId);

  final String optionId;

  @override
  Map<String, dynamic> toJson() => {'option_id': optionId};
}

class TextReply extends ReplyBody {
  const TextReply(this.text);

  final String text;

  @override
  Map<String, dynamic> toJson() => {'text': text};
}

/// The one-time link for "continue in browser".
class HandoffLink {
  const HandoffLink({
    required this.url,
    this.expiresAt,
    this.simulated = false,
  });

  final Uri url;
  final DateTime? expiresAt;

  /// The mock transport's link: nothing is opened, the step just completes.
  final bool simulated;
}

/// The business's look, from `GET /v1/config`.
class ChatConfig {
  const ChatConfig({
    required this.botName,
    this.statusText,
    this.logoUrl,
    this.coverUrl,
    this.initial,
    this.palette,
    this.pattern,
    this.poweredBy = true,
    this.supportPhone,
    this.canResume = false,
    this.canPush = false,
    this.isTest = false,
  });

  factory ChatConfig.fromJson(Map<String, dynamic> json) {
    final logo = _str(json['logo_url']);
    final cover = _str(json['cover_url']);
    final colors = _map(json['colors']);
    final features = _map(json['features']);
    return ChatConfig(
      botName: _str(json['bot_name']) ?? '',
      statusText: _str(json['status_text']),
      logoUrl: logo != null && _isHttpUrl(logo) ? logo : null,
      coverUrl: cover != null && _isHttpUrl(cover) ? cover : null,
      initial: _str(json['initial']),
      pattern: _str(json['pattern']),
      poweredBy: json['powered_by'] != false,
      supportPhone: _str(json['support_phone']),
      palette: colors.isEmpty ? null : TenantPalette.fromJson(colors),
      canResume: features['resume'] == true,
      canPush: features['push'] == true,
      isTest: json['environment'] == 'test',
    );
  }

  final String botName;
  final String? statusText;
  final String? logoUrl;
  final String? initial;
  final String? coverUrl;
  final TenantPalette? palette;

  /// Wall pattern: stars, arches, dots, waves or none.
  final String? pattern;
  final bool poweredBy;
  final String? supportPhone;

  /// `POST /conversations/resume` is available.
  final bool canResume;

  /// `POST /push-token` is accepted.
  final bool canPush;

  /// The key is a `rpk_test_` key.
  final bool isTest;

  String get avatarInitial {
    final i = initial;
    if (i != null && i.isNotEmpty) return i.characters1;
    return botName.isEmpty ? '•' : botName.characters1;
  }
}

/// The tenant's colours as the server computes them (contrast-safe). Any
/// missing tone is derived from [primary] on the device.
class TenantPalette {
  const TenantPalette({
    required this.primary,
    this.primaryFg,
    this.primaryStrong,
    this.primaryTint,
    this.primaryDark,
  });

  static TenantPalette? fromJson(Map<String, dynamic> json) {
    final primary = parseHexColor(json['primary']);
    if (primary == null) return null;
    return TenantPalette(
      primary: primary,
      primaryFg: parseHexColor(json['primary_fg']),
      primaryStrong: parseHexColor(json['primary_strong']),
      primaryTint: parseHexColor(json['primary_tint']),
      primaryDark: parseHexColor(json['primary_dark']),
    );
  }

  final Color primary;
  final Color? primaryFg;
  final Color? primaryStrong;
  final Color? primaryTint;
  final Color? primaryDark;
}

/// `#rrggbb` only. Anything else (names, short forms, injections) is null.
Color? parseHexColor(Object? value) {
  if (value is! String) return null;
  final m = RegExp(r'^#([0-9a-fA-F]{6})$').firstMatch(value.trim());
  if (m == null) return null;
  return Color(0xFF000000 | int.parse(m.group(1)!, radix: 16));
}

/// An API error with a stable [code] (e.g. `session_not_found`).
class RaselnaException implements Exception {
  const RaselnaException(
    this.code, {
    this.status,
    this.message,
    this.reason,
    this.retryAfter,
  });

  final String code;
  final int? status;

  /// The server's human message (a short Arabic sentence, safe to show).
  final String? message;

  /// `paused` only: `billing`, `usage_limit` or `unavailable`.
  final String? reason;

  /// From `Retry-After` (429, 503).
  final Duration? retryAfter;

  @override
  String toString() => 'RaselnaException($code, status: $status)';
}

/// The request never reached the server (offline, timeout, DNS).
class RaselnaNetworkException implements Exception {
  const RaselnaNetworkException([this.cause]);

  final Object? cause;

  @override
  String toString() => 'RaselnaNetworkException';
}

Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : const {};

String? _str(Object? value) =>
    value is String && value.trim().isNotEmpty ? value : null;

bool _isHttpUrl(String url) {
  final u = Uri.tryParse(url);
  return u != null &&
      (u.scheme == 'https' || u.scheme == 'http') &&
      u.host.isNotEmpty;
}

extension on String {
  /// The first user-perceived character (good enough for Arabic and Latin).
  String get characters1 {
    final runes = this.runes;
    return runes.isEmpty ? '' : String.fromCharCode(runes.first);
  }
}
