import 'package:flutter/material.dart';

import '../controller.dart';
import '../models.dart';
import '../raselna_chat.dart';
import '../strings.dart';
import '../theme.dart';
import 'bubbles.dart';
import 'composer.dart';
import 'header.dart';
import 'prompts.dart';
import 'shop.dart';

/// The chat screen. Put it anywhere (a tab, a page, a sheet). With no
/// [controller] it uses the one `RaselnaChat.init` created.
class RaselnaChatView extends StatefulWidget {
  const RaselnaChatView({
    super.key,
    this.controller,
    this.theme,
    this.themeMode,
    this.locale,
    this.strings,
    this.showHeader = true,
    this.onClose,
  });

  final RaselnaChatController? controller;

  /// Overrides on top of the business's colours.
  final RaselnaChatTheme? theme;

  /// `system` (default) follows the app's own `Theme` brightness.
  final ThemeMode? themeMode;

  /// `ar` (default, right to left) or `en`.
  final String? locale;
  final RaselnaStrings? strings;
  final bool showHeader;

  /// Shows a back button in the header.
  final VoidCallback? onClose;

  @override
  State<RaselnaChatView> createState() => _RaselnaChatViewState();
}

class _RaselnaChatViewState extends State<RaselnaChatView>
    with WidgetsBindingObserver {
  late RaselnaChatController _controller;

  RaselnaChatController _resolve() =>
      widget.controller ?? RaselnaChat.controller;

  @override
  void initState() {
    super.initState();
    _controller = _resolve();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.load();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.animateTyping = false;
    }
  }

  @override
  void didUpdateWidget(RaselnaChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _resolve();
    if (!identical(next, _controller)) {
      _controller = next;
      _controller.load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _controller.onResumed();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = widget.locale ?? RaselnaChat.locale;
    final strings = widget.strings ?? RaselnaChat.stringsFor(locale);
    final direction =
        locale.toLowerCase().startsWith('ar')
            ? TextDirection.rtl
            : TextDirection.ltr;
    final mode = widget.themeMode ?? RaselnaChat.themeMode;

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final brightness = switch (mode) {
          ThemeMode.light => Brightness.light,
          ThemeMode.dark => Brightness.dark,
          ThemeMode.system => Theme.of(context).brightness,
        };
        final colors = RaselnaChatColors.resolve(
          palette: _controller.config?.palette,
          brightness: brightness,
          overrides: widget.theme ?? RaselnaChat.theme,
        );
        return RaselnaChatColorsScope(
          colors: colors,
          child: Directionality(
            textDirection: direction,
            child: Material(
              color: colors.background,
              child: _Body(
                controller: _controller,
                strings: strings,
                colors: colors,
                direction: direction,
                showHeader: widget.showHeader,
                onClose: widget.onClose,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.controller,
    required this.strings,
    required this.colors,
    required this.direction,
    required this.showHeader,
    required this.onClose,
  });

  final RaselnaChatController controller;
  final RaselnaStrings strings;
  final RaselnaChatColors colors;
  final TextDirection direction;
  final bool showHeader;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final ctl = controller;
    final status =
        ctl.isTyping
            ? strings.typing
            : ctl.phase == ChatPhase.loading
            ? strings.connecting
            : (ctl.config?.statusText ?? strings.online);

    return Column(
      children: [
        if (showHeader)
          ChatHeader(
            config: ctl.config,
            status: status,
            onClose: onClose,
            closeLabel: strings.close,
          ),
        if (ctl.isOffline && ctl.phase == ChatPhase.ready)
          Container(
            width: double.infinity,
            color: c.warning.withValues(alpha: c.isDark ? 0.18 : 0.12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Semantics(
              liveRegion: true,
              child: Text(
                strings.offline,
                textAlign: TextAlign.center,
                style: c.style(size: 13, color: c.isDark ? c.warning : c.text),
              ),
            ),
          ),
        Expanded(
          child: Stack(
            children: [
              if (c.showPattern)
                Positioned.fill(
                  child: CustomPaint(
                    painter: ChatPattern(
                      c.accent.withValues(alpha: c.isDark ? 0.09 : 0.07),
                    ),
                  ),
                ),
              Positioned.fill(child: _content(context)),
            ],
          ),
        ),
        _bottom(context),
      ],
    );
  }

  Widget _content(BuildContext context) {
    final c = colors;
    final ctl = controller;
    switch (ctl.phase) {
      case ChatPhase.idle:
      case ChatPhase.loading:
        if (ctl.entries.isEmpty) {
          return Center(child: CircularProgressIndicator(color: c.accent));
        }
      case ChatPhase.failed:
        final e = ctl.error;
        final message =
            e is RaselnaException && e.status == 429
                ? strings.tooMany
                : e is RaselnaException && e.status == 503
                ? (e.message ?? strings.unavailable)
                : e is RaselnaNetworkException
                ? strings.offline
                : strings.loadFailed;
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off_outlined, size: 40, color: c.mutedText),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: c.style(color: c.mutedText),
                ),
                const SizedBox(height: 16),
                ReplyChip(
                  label: strings.tryAgain,
                  icon: Icons.refresh,
                  onTap: ctl.load,
                ),
              ],
            ),
          ),
        );
      case ChatPhase.ready:
        break;
    }

    final entries = ctl.entries;
    final prompt = ctl.prompt;
    final rich = _shownRich;
    final botName = ctl.config?.botName ?? '';
    final items = <Widget>[
      SystemLine(text: _today()),
      for (var i = 0; i < entries.length; i++)
        ChatBubble(
          key: ValueKey(entries[i].key),
          entry: entries[i],
          botName: botName,
          strings: strings,
          lastInGroup:
              i == entries.length - 1 || entries[i + 1].side != entries[i].side,
          onRetry:
              ctl.canRetry(entries[i].key)
                  ? () => ctl.retry(entries[i].key)
                  : null,
        ),
      if (ctl.isTyping) TypingIndicator(label: strings.typing),
      ...switch (prompt) {
        final MenuPrompt m when m.display == MenuDisplay.buttons => [
          QuickReplies(prompt: m, onChoose: ctl.choose),
        ],
        final SlotsPrompt p => [
          SlotPicker(prompt: p, strings: strings, onChoose: ctl.chooseSlot),
        ],
        final HandoffPrompt p => [
          HandoffCard(
            prompt: p,
            strings: strings,
            waiting: ctl.isHandoffOpen,
            onOpen: () async {
              final ok = await ctl.openHandoff();
              if (!ok && context.mounted) {
                ScaffoldMessenger.maybeOf(
                  context,
                )?.showSnackBar(SnackBar(content: Text(strings.handoffFailed)));
              }
            },
            onBack: ctl.refresh,
          ),
        ],
        PausedPrompt(:final code) when code.isNotEmpty => [
          PausedCard(code: code, strings: strings),
        ],
        _ => const <Widget>[],
      },
      if (rich != null)
        _richCard(
          context,
          rich,
          enabled: rich.isRichNative && identical(rich, prompt),
        ),
    ];

    // Reversed, so the newest line sits at the bottom and the list keeps
    // to it as messages arrive.
    return ListView(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: items.reversed.toList(),
    );
  }

  Widget _bottom(BuildContext context) {
    final c = colors;
    final ctl = controller;
    final prompt = ctl.prompt;
    final ready = ctl.phase == ChatPhase.ready;

    Widget? bar;
    final rich = _shownRich;
    if (ready && rich != null) {
      bar = _richBar(context, rich, enabled: identical(rich, prompt));
    } else if (ready) {
      bar = switch (prompt) {
        InputPrompt(:final inputKind, :final placeholder, :final progress) =>
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (progress != null)
                _Progress(progress: progress, strings: strings),
              Composer(
                strings: strings,
                inputKind: inputKind,
                placeholder: placeholder,
                onSend: (t) => ctl.sendText(t),
              ),
            ],
          ),
        final MenuPrompt m when m.display == MenuDisplay.list => ReplyChip(
          label: m.listButtonText ?? strings.showOptions,
          icon: Icons.format_list_bulleted,
          filled: true,
          onTap: () async {
            final picked = await showOptionsSheet(
              context,
              prompt: m,
              colors: c,
              strings: strings,
              direction: direction,
            );
            if (picked != null) await ctl.choose(picked);
          },
        ),
        MenuPrompt() => Composer(
          strings: strings,
          placeholder: strings.chooseOption,
          validate: false,
          onSend: (t) => ctl.sendText(t),
        ),
        EndPrompt(:final showRestart) =>
          showRestart
              ? ReplyChip(
                label: strings.restart,
                icon: Icons.replay,
                filled: true,
                onTap: ctl.restart,
              )
              : Text(
                strings.ended,
                textAlign: TextAlign.center,
                style: c.style(color: c.mutedText),
              ),
        PausedPrompt() => Row(
          children: [
            Expanded(
              child: ReplyChip(
                label: strings.continueBack,
                filled: true,
                onTap: ctl.continueConversation,
              ),
            ),
            const SizedBox(width: 8),
            ReplyChip(label: strings.restart, onTap: ctl.restart),
          ],
        ),
        SlotsPrompt() ||
        HandoffPrompt() ||
        ProductListPrompt() ||
        CartPrompt() ||
        FormPrompt() => null,
        NonePrompt() => Composer(
          strings: strings,
          enabled: false,
          onSend: (_) {},
        ),
      };
    }

    final powered = ctl.config?.poweredBy ?? true;
    return Container(
      decoration: BoxDecoration(
        color: c.background,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (bar != null) bar,
              if (powered)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '${strings.poweredBy} '),
                        TextSpan(
                          text: strings.raselna,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: c.mutedText,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    style: c.style(size: 11.5, color: c.mutedText, height: 1.2),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// The rich step to draw: the live prompt, or the last one (disabled)
  /// while an answer is on its way.
  Prompt? get _shownRich {
    final ctl = controller;
    if (ctl.prompt.isRichNative) return ctl.prompt;
    if (ctl.isBusy || ctl.queuedCount > 0) return ctl.richPrompt;
    return null;
  }

  RaselnaShopStrings get _s => strings.shop;

  Widget _richCard(BuildContext context, Prompt rich, {required bool enabled}) {
    final ctl = controller;
    return switch (rich) {
      final ProductListPrompt p when p.isPick => PickResults(
        prompt: p,
        strings: strings,
        onDetails:
            (product) => _openPick(context, p, product, enabled: enabled),
        onSelect: enabled ? (product) => _select(product) : null,
      ),
      final ProductListPrompt p => CatalogCard(
        prompt: p,
        strings: strings,
        onBrowse: () => _openCatalog(context),
      ),
      final CartPrompt p => CartCard(
        prompt: p,
        strings: strings,
        onQty:
            enabled
                ? (line, q) => ctl.act(
                  q <= 0
                      ? ActionReply('remove', line: line.id)
                      : ActionReply('set_qty', line: line.id, qty: q),
                  echo:
                      q <= 0
                          ? _s.removed.replaceAll('{name}', line.name)
                          : _s.changed
                              .replaceAll('{name}', line.name)
                              .replaceAll('{qty}', qtyText(q)),
                )
                : null,
      ),
      final FormPrompt p when p.isRange => RangeCard(
        prompt: p,
        strings: strings,
        onSubmit:
            enabled
                ? (min, max) => ctl.act(
                  ActionReply('submit', values: {'min': min, 'max': max}),
                  echo:
                      min.isNotEmpty && max.isNotEmpty
                          ? '$min – $max'
                          : min.isNotEmpty
                          ? '${_s.from} $min'
                          : max.isNotEmpty
                          ? '${_s.to} $max'
                          : _s.anyRange,
                )
                : null,
      ),
      final FormPrompt p => FormCard(
        prompt: p,
        strings: strings,
        onOpen: enabled ? () => _openForm(context, p) : null,
      ),
      _ => const SizedBox.shrink(),
    };
  }

  Widget? _richBar(BuildContext context, Prompt rich, {required bool enabled}) {
    final ctl = controller;
    switch (rich) {
      case final ProductListPrompt p when p.isPick:
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            if (p.hasMore)
              ShopButton(
                label: p.moreLabel ?? _s.more,
                onTap:
                    enabled
                        ? () => ctl.act(
                          const ActionReply('more'),
                          echo: p.moreLabel ?? _s.more,
                        )
                        : null,
              ),
            ShopButton(
              label: p.restartLabel ?? _s.startOver,
              primary: false,
              onTap:
                  enabled
                      ? () => ctl.act(
                        const ActionReply('restart'),
                        echo: p.restartLabel ?? _s.startOver,
                      )
                      : null,
            ),
            if (p.contactLabel != null)
              ShopButton(
                label: p.contactLabel!,
                primary: false,
                onTap:
                    enabled
                        ? () => ctl.act(
                          const ActionReply('contact'),
                          echo: p.contactLabel!,
                        )
                        : null,
              ),
          ],
        );
      case final ProductListPrompt p:
        return CatalogBar(
          prompt: p,
          strings: strings,
          onBrowse: () => _openCatalog(context),
          onDone:
              enabled
                  ? () => ctl.act(
                    const ActionReply('done'),
                    echo: p.doneLabel ?? _s.cart,
                  )
                  : null,
        );
      case final CartPrompt p:
        return Row(
          children: [
            Expanded(
              child: ShopButton(
                label: p.moreLabel ?? _s.menu,
                primary: false,
                onTap:
                    enabled
                        ? () => ctl.act(
                          const ActionReply('more'),
                          echo: p.moreLabel ?? _s.menu,
                        )
                        : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ShopButton(
                label: p.confirmLabel ?? _s.sendOrder,
                onTap:
                    enabled && p.canCheckout
                        ? () => ctl.act(
                          const ActionReply('confirm'),
                          echo: p.confirmLabel ?? _s.sendOrder,
                        )
                        : null,
              ),
            ),
          ],
        );
      default:
        return null;
    }
  }

  Future<void> _openCatalog(BuildContext context) => showChatSheet<void>(
    context,
    colors: colors,
    direction: direction,
    builder:
        (_) => CatalogSheet(
          controller: controller,
          strings: strings,
          onOpenProduct: _openProduct,
        ),
  );

  Future<void> _openProduct(BuildContext sheetContext, Product product) async {
    final pick = await showChatSheet<ProductPick>(
      sheetContext,
      colors: colors,
      direction: direction,
      heightFactor: 0.85,
      builder: (_) => ProductSheet(product: product, strings: _s),
    );
    if (pick == null) return;
    await controller.act(
      ActionReply(
        'add',
        product: product.id,
        qty: pick.qty,
        options: pick.options,
      ),
      echo: _s.added
          .replaceAll('{qty}', qtyText(pick.qty))
          .replaceAll('{name}', product.name),
    );
  }

  Future<void> _openPick(
    BuildContext context,
    ProductListPrompt p,
    Product product, {
    required bool enabled,
  }) async {
    final chosen = await showChatSheet<bool>(
      context,
      colors: colors,
      direction: direction,
      builder:
          (_) => PickDetails(
            product: product,
            strings: _s,
            selectLabel: p.selectLabel ?? _s.choose,
            enabled: enabled,
          ),
    );
    if (chosen == true) await _select(product);
  }

  Future<void> _select(Product product) => controller.act(
    ActionReply('select', product: product.id),
    echo: _s.chose.replaceAll('{name}', product.name),
  );

  Future<void> _openForm(BuildContext context, FormPrompt p) async {
    final values = await showChatSheet<Map<String, String>>(
      context,
      colors: colors,
      direction: direction,
      builder: (_) => FormSheet(prompt: p, strings: strings),
    );
    if (values == null) return;
    await controller.act(ActionReply('submit', values: values), echo: _s.sent);
  }

  String _today() => direction == TextDirection.rtl ? 'اليوم' : 'Today';
}

class _Progress extends StatelessWidget {
  const _Progress({required this.progress, required this.strings});

  final StepProgress progress;
  final RaselnaStrings strings;

  @override
  Widget build(BuildContext context) {
    final c = RaselnaChatColors.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(6, 0, 6, 8),
      child: Row(
        children: [
          Text(
            strings.stepOf
                .replaceAll('{n}', '${progress.step}')
                .replaceAll('{m}', '${progress.total}'),
            style: c.style(
              size: 12.5,
              weight: FontWeight.w500,
              color: c.mutedText,
              height: 1.2,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.step / progress.total,
                minHeight: 4,
                backgroundColor: c.border,
                color: c.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
