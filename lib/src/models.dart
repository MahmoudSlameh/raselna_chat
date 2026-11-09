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
    // A secret question always continues on the secure web page (system
    // browser), whatever its kind. A rich step the SDK draws natively stays
    // native even if an older server flags it for the browser; anything
    // else the server sends to the browser goes there.
    final handoff = _map(json['handoff']);
    if (handoff['reason'] == 'secret') {
      if (prompt is! HandoffPrompt || prompt.reason != HandoffReason.secret) {
        prompt = HandoffPrompt(kind: prompt.kind, reason: HandoffReason.secret);
      }
    } else if (handoff['required'] == true &&
        prompt is! HandoffPrompt &&
        !prompt.isRichNative) {
      prompt = HandoffPrompt(kind: prompt.kind, reason: HandoffReason.unknown);
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

  /// A rich step (catalogue, cart, form) drawn natively by this SDK.
  bool get isRichNative =>
      this is ProductListPrompt || this is CartPrompt || this is FormPrompt;

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
      // A mode this SDK version doesn't know is drawn on the web chat.
      case 'product_list' when json['mode'] == null || json['mode'] == 'pick':
        return ProductListPrompt.fromJson(json);
      case 'cart':
        return CartPrompt.fromJson(json);
      case 'form' when json['mode'] == null || json['mode'] == 'range':
        return FormPrompt.fromJson(json);
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

/// Why a step opens the browser. Since 0.2.0 only [secret] and [unknown]
/// are produced; catalogue, cart and form are drawn natively.
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

/// A rich-step action (catalogue, cart, form, finder). Ids are the
/// server's opaque per-prompt tokens; never a price.
class ActionReply extends ReplyBody {
  const ActionReply(
    this.type, {
    this.product,
    this.line,
    this.qty,
    this.options,
    this.values,
  });

  /// `add`, `done`, `set_qty`, `remove`, `more`, `confirm`, `submit`,
  /// `select`, `restart` or `contact`.
  final String type;
  final String? product;
  final String? line;
  final num? qty;
  final List<String>? options;
  final Map<String, String>? values;

  @override
  Map<String, dynamic> toJson() => {
    'action': {
      'type': type,
      if (product != null) 'product': product,
      if (line != null) 'line': line,
      if (qty != null) 'qty': qty,
      if (options != null && options!.isNotEmpty) 'options': options,
      if (values != null) 'values': values,
    },
  };
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

// --- Rich steps, drawn natively since 0.2.0 ---------------------------------

/// A label and a value (product attributes and details, form summaries).
class LabelValue {
  const LabelValue(this.label, this.value);

  static List<LabelValue> listFromJson(Object? raw) =>
      raw is List
          ? [
            for (final m in raw.whereType<Map>())
              if (m['label'] is String && m['value'] is String)
                LabelValue(m['label'] as String, m['value'] as String),
          ]
          : const [];

  final String label;
  final String value;
}

class ProductCategory {
  const ProductCategory({required this.id, required this.name});

  final String id;
  final String name;
}

class ProductChoice {
  const ProductChoice({required this.id, required this.name, this.price});

  final String id;
  final String name;

  /// Display text such as "+2,000 ل.س"; never computed with.
  final String? price;
}

/// An option group of a product (size, filling). One choice per group.
class ProductGroup {
  const ProductGroup({
    required this.name,
    this.required = false,
    this.choices = const [],
  });

  final String name;
  final bool required;
  final List<ProductChoice> choices;
}

/// A product card. Prices are display strings computed by the server.
class Product {
  const Product({
    required this.id,
    required this.name,
    this.category,
    this.description,
    this.price,
    this.unit,
    this.step = 1,
    this.max = 99,
    this.imageUrl,
    this.available = true,
    this.groups = const [],
    this.categoryName,
    this.code,
    this.priceHint,
    this.images = const [],
    this.attributes = const [],
    this.details = const [],
  });

  factory Product.fromJson(Map<dynamic, dynamic> j) {
    final groups = j['groups'];
    final images = j['images'];
    final image = _str(j['image_url']);
    return Product(
      id: _str(j['id']) ?? '',
      name: _str(j['name']) ?? '',
      category: _str(j['category']),
      description: _str(j['description']),
      price: _str(j['price']),
      unit: _str(j['unit']),
      step: j['step'] is num && (j['step'] as num) > 0 ? j['step'] as num : 1,
      max: j['max'] is num && (j['max'] as num) > 0 ? j['max'] as num : 99,
      imageUrl: image != null && _isHttpUrl(image) ? image : null,
      available: j['available'] != false,
      categoryName: _str(j['category_name']),
      code: _str(j['code']),
      priceHint: _str(j['price_hint']),
      images:
          images is List
              ? [
                for (final u in images.whereType<String>())
                  if (_isHttpUrl(u)) u,
              ]
              : const [],
      attributes: LabelValue.listFromJson(j['attributes']),
      details: LabelValue.listFromJson(j['details']),
      groups:
          groups is List
              ? [
                for (final g in groups.whereType<Map>())
                  ProductGroup(
                    name: _str(g['name']) ?? '',
                    required: g['required'] == true,
                    choices:
                        g['choices'] is List
                            ? [
                              for (final c
                                  in (g['choices'] as List).whereType<Map>())
                                if (c['id'] is String && c['name'] is String)
                                  ProductChoice(
                                    id: c['id'] as String,
                                    name: c['name'] as String,
                                    price: _str(c['price']),
                                  ),
                            ]
                            : const [],
                  ),
              ]
              : const [],
    );
  }

  final String id;
  final String name;
  final String? category;
  final String? description;
  final String? price;
  final String? unit;

  /// Quantity step (e.g. 0.25 kg) and maximum.
  final num step;
  final num max;
  final String? imageUrl;
  final bool available;
  final List<ProductGroup> groups;

  // Finder results (`mode = pick`).
  final String? categoryName;
  final String? code;
  final String? priceHint;
  final List<String> images;
  final List<LabelValue> attributes;
  final List<LabelValue> details;

  /// The first picture, if any.
  String? get picture => imageUrl ?? (images.isEmpty ? null : images.first);
}

/// The catalogue (ordering), or the product finder's results when [isPick].
class ProductListPrompt extends Prompt {
  const ProductListPrompt({
    this.categories = const [],
    this.products = const [],
    this.cartCount = 0,
    this.cartTotal,
    this.notice,
    this.doneLabel,
    this.emptyText,
    this.isPick = false,
    this.total,
    this.hasMore = false,
    this.moreLabel,
    this.selectLabel,
    this.detailsLabel,
    this.restartLabel,
    this.contactLabel,
  });

  factory ProductListPrompt.fromJson(Map<String, dynamic> json) {
    final cats = json['categories'];
    final products = json['products'];
    final cart = _map(json['cart']);
    return ProductListPrompt(
      categories:
          cats is List
              ? [
                for (final c in cats.whereType<Map>())
                  if (c['id'] is String && c['name'] is String)
                    ProductCategory(
                      id: c['id'] as String,
                      name: c['name'] as String,
                    ),
              ]
              : const [],
      products:
          products is List
              ? [
                for (final p in products.whereType<Map>()) Product.fromJson(p),
              ].where((p) => p.id.isNotEmpty).toList(growable: false)
              : const [],
      cartCount: cart['count'] is int ? cart['count'] as int : 0,
      cartTotal: _str(cart['total']),
      notice: _str(json['notice']),
      doneLabel: _str(json['done_label']),
      emptyText: _str(json['empty_text']),
      isPick: json['mode'] == 'pick',
      total: json['total'] is int ? json['total'] as int : null,
      hasMore: json['has_more'] == true,
      moreLabel: _str(json['more_label']),
      selectLabel: _str(json['select_label']),
      detailsLabel: _str(json['details_label']),
      restartLabel: _str(json['restart_label']),
      contactLabel: _str(json['contact_label']),
    );
  }

  final List<ProductCategory> categories;
  final List<Product> products;
  final int cartCount;
  final String? cartTotal;
  final String? notice;
  final String? doneLabel;
  final String? emptyText;

  /// The finder's results: pick one product, no cart.
  final bool isPick;
  final int? total;
  final bool hasMore;
  final String? moreLabel;
  final String? selectLabel;
  final String? detailsLabel;
  final String? restartLabel;
  final String? contactLabel;

  @override
  String get kind => 'product_list';
}

class CartLine {
  const CartLine({
    required this.id,
    required this.name,
    this.options,
    this.qty = 1,
    this.qtyText,
    this.step = 1,
    this.max = 99,
    this.unit,
    this.unitPrice,
    this.total,
  });

  final String id;
  final String name;
  final String? options;
  final num qty;
  final String? qtyText;
  final num step;
  final num max;
  final String? unit;
  final String? unitPrice;
  final String? total;
}

/// The cart: lines with server totals; quantities change through actions.
class CartPrompt extends Prompt {
  const CartPrompt({
    this.lines = const [],
    this.subtotal,
    this.notice,
    this.canCheckout = false,
    this.moreLabel,
    this.confirmLabel,
    this.emptyText,
  });

  factory CartPrompt.fromJson(Map<String, dynamic> json) {
    final lines = json['lines'];
    num n(Object? v, num d) => v is num && v >= 0 ? v : d;
    return CartPrompt(
      lines:
          lines is List
              ? [
                for (final l in lines.whereType<Map>())
                  if (l['id'] is String)
                    CartLine(
                      id: l['id'] as String,
                      name: _str(l['name']) ?? '',
                      options: _str(l['options']),
                      qty: n(l['qty'], 1),
                      qtyText: _str(l['qty_text']),
                      step: n(l['step'], 1) == 0 ? 1 : n(l['step'], 1),
                      max: n(l['max'], 99),
                      unit: _str(l['unit']),
                      unitPrice: _str(l['unit_price']),
                      total: _str(l['total']),
                    ),
              ]
              : const [],
      subtotal: _str(json['subtotal']),
      notice: _str(json['notice']),
      canCheckout: json['can_checkout'] == true,
      moreLabel: _str(json['more_label']),
      confirmLabel: _str(json['confirm_label']),
      emptyText: _str(json['empty_text']),
    );
  }

  final List<CartLine> lines;
  final String? subtotal;
  final String? notice;
  final bool canCheckout;
  final String? moreLabel;
  final String? confirmLabel;
  final String? emptyText;

  @override
  String get kind => 'cart';
}

class FieldOption {
  const FieldOption({required this.id, required this.label, this.hint});

  final String id;
  final String label;
  final String? hint;
}

/// The kind of a form field. Unknown types are drawn as [text].
enum FormFieldKind {
  text,
  textarea,
  phone,
  choice;

  static FormFieldKind parse(String? raw) => switch (raw) {
    'textarea' => FormFieldKind.textarea,
    'phone' || 'tel' => FormFieldKind.phone,
    'choice' => FormFieldKind.choice,
    _ => FormFieldKind.text,
  };
}

class FormFieldSpec {
  const FormFieldSpec({
    required this.name,
    required this.label,
    this.type = FormFieldKind.text,
    this.rawType,
    this.required = false,
    this.value,
    this.error,
    this.placeholder,
    this.options = const [],
    this.showIfField,
    this.showIfValue,
  });

  final String name;
  final String label;
  final FormFieldKind type;

  /// The server's type string, as sent.
  final String? rawType;
  final bool required;
  final String? value;

  /// The server's message for this field (after a refused submit).
  final String? error;
  final String? placeholder;
  final List<FieldOption> options;

  /// Shown only while field [showIfField] has the value [showIfValue].
  final String? showIfField;
  final String? showIfValue;
}

/// A form on one screen: checkout details, or the finder's min/max
/// ([isRange]). Answered with a `submit` action.
class FormPrompt extends Prompt {
  const FormPrompt({
    this.fields = const [],
    this.title,
    this.submitLabel,
    this.openLabel,
    this.error,
    this.isRange = false,
    this.summary = const [],
  });

  factory FormPrompt.fromJson(Map<String, dynamic> json) {
    final fields = json['fields'];
    return FormPrompt(
      title: _str(json['title']),
      submitLabel: _str(json['submit_label']),
      openLabel: _str(json['open_label']),
      error: _str(json['error']),
      isRange: json['mode'] == 'range',
      summary: LabelValue.listFromJson(json['summary']),
      fields:
          fields is List
              ? [
                for (final f in fields.whereType<Map>())
                  if (f['name'] is String)
                    FormFieldSpec(
                      name: f['name'] as String,
                      label: _str(f['label']) ?? f['name'] as String,
                      type: FormFieldKind.parse(_str(f['type'])),
                      rawType: _str(f['type']),
                      required: f['required'] == true,
                      value: f['value'] is String ? f['value'] as String : null,
                      error: _str(f['error']),
                      placeholder: _str(f['placeholder']),
                      options:
                          f['options'] is List
                              ? [
                                for (final o
                                    in (f['options'] as List).whereType<Map>())
                                  if (o['id'] is String && o['label'] is String)
                                    FieldOption(
                                      id: o['id'] as String,
                                      label: o['label'] as String,
                                      hint: _str(o['hint']),
                                    ),
                              ]
                              : const [],
                      showIfField:
                          f['show_if'] is Map
                              ? _str((f['show_if'] as Map)['field'])
                              : null,
                      showIfValue:
                          f['show_if'] is Map
                              ? _str((f['show_if'] as Map)['value'])
                              : null,
                    ),
              ]
              : const [],
    );
  }

  final List<FormFieldSpec> fields;
  final String? title;
  final String? submitLabel;
  final String? openLabel;

  /// A message for the whole form (after a refused submit).
  final String? error;

  /// The finder's price range: two number fields, both optional.
  final bool isRange;
  final List<LabelValue> summary;

  bool get hasErrors => error != null || fields.any((f) => f.error != null);

  @override
  String get kind => 'form';
}
