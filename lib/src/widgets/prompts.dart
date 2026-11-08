import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../strings.dart';
import '../theme.dart';

/// A tappable chip in the tenant's soft tone (quick replies, slots).
class ReplyChip extends StatelessWidget {
  const ReplyChip({
    super.key,
    required this.label,
    required this.onTap,
    this.filled = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onTap;
  final bool filled;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = RaselnaChatColors.of(context);
    final fg = filled ? c.onPrimary : c.onTint;
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: Material(
        color: filled ? c.primary : c.tint,
        shape: StadiumBorder(
          side: BorderSide(
            color: filled ? c.primary : c.accent.withValues(alpha: 0.35),
          ),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap:
              onTap == null
                  ? null
                  : () {
                    HapticFeedback.selectionClick();
                    onTap!();
                  },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: fg),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: c.style(
                        size: 14.5,
                        weight: FontWeight.w500,
                        color: fg,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Up to three quick replies under the last bot bubble.
class QuickReplies extends StatelessWidget {
  const QuickReplies({super.key, required this.prompt, required this.onChoose});

  final MenuPrompt prompt;
  final ValueChanged<MenuOption>? onChoose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 10),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in prompt.options)
              ReplyChip(
                label: o.label,
                onTap: onChoose == null ? null : () => onChoose!(o),
              ),
          ],
        ),
      ),
    );
  }
}

/// Opens the numbered option list (4+ options) in a bottom sheet.
Future<MenuOption?> showOptionsSheet(
  BuildContext context, {
  required MenuPrompt prompt,
  required RaselnaChatColors colors,
  required RaselnaStrings strings,
  required TextDirection direction,
}) {
  return showModalBottomSheet<MenuOption>(
    context: context,
    isScrollControlled: true,
    backgroundColor: colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder:
        (context) => RaselnaChatColorsScope(
          colors: colors,
          child: Directionality(
            textDirection: direction,
            child: SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.75,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 10),
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        20,
                        14,
                        20,
                        8,
                      ),
                      child: Text(
                        prompt.listButtonText ?? strings.showOptions,
                        style: colors.style(size: 16, weight: FontWeight.w700),
                      ),
                    ),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.only(bottom: 12),
                        itemCount: prompt.options.length,
                        separatorBuilder:
                            (_, _) => Divider(
                              height: 1,
                              color: colors.border,
                              indent: 64,
                            ),
                        itemBuilder: (context, i) {
                          final o = prompt.options[i];
                          return InkWell(
                            onTap: () => Navigator.of(context).pop(o),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 56),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: colors.tint,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        '${o.index}',
                                        style: colors.style(
                                          size: 14,
                                          weight: FontWeight.w700,
                                          color: colors.onTint,
                                          height: 1,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        o.label,
                                        style: colors.style(size: 15.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
  );
}

/// A rounded card in the conversation, at the bot's side.
class ChatCard extends StatelessWidget {
  const ChatCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = RaselnaChatColors.of(context);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.88,
        ),
        padding: padding,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(c.radius),
          border: Border.all(color: c.border),
        ),
        child: child,
      ),
    );
  }
}

/// Day or time chips, in groups ("Morning", "Evening"), plus actions such
/// as "Other days". Answered with a plain option reply.
class SlotPicker extends StatelessWidget {
  const SlotPicker({
    super.key,
    required this.prompt,
    required this.strings,
    required this.onChoose,
  });

  final SlotsPrompt prompt;
  final RaselnaStrings strings;
  final ValueChanged<SlotOption>? onChoose;

  @override
  Widget build(BuildContext context) {
    final c = RaselnaChatColors.of(context);
    final empty = prompt.groups.every((g) => g.options.isEmpty);
    return ChatCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event_available_outlined, size: 20, color: c.accent),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  prompt.title ?? '',
                  style: c.style(size: 15, weight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (empty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                prompt.emptyText ?? strings.slotsEmpty,
                style: c.style(size: 14, color: c.mutedText),
              ),
            ),
          for (final g in prompt.groups)
            if (g.options.isNotEmpty) ...[
              if (g.label != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 6),
                  child: Text(
                    g.label!,
                    style: c.style(
                      size: 13,
                      weight: FontWeight.w500,
                      color: c.mutedText,
                    ),
                  ),
                )
              else
                const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final o in g.options)
                    ReplyChip(
                      label: o.label,
                      onTap: onChoose == null ? null : () => onChoose!(o),
                    ),
                ],
              ),
            ],
          if (prompt.actions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 4,
              children: [
                for (final a in prompt.actions)
                  TextButton(
                    onPressed: onChoose == null ? null : () => onChoose!(a),
                    style: TextButton.styleFrom(
                      foregroundColor: c.accent,
                      minimumSize: const Size(48, 44),
                    ),
                    child: Text(
                      a.label,
                      style: c.style(
                        size: 14,
                        weight: FontWeight.w700,
                        color: c.accent,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// "This step continues on a secure page": the rich steps (catalog, cart,
/// form), secret inputs and any step this SDK version does not know.
class HandoffCard extends StatelessWidget {
  const HandoffCard({
    super.key,
    required this.prompt,
    required this.strings,
    required this.waiting,
    required this.onOpen,
    required this.onBack,
  });

  final HandoffPrompt prompt;
  final RaselnaStrings strings;

  /// The customer opened the page and has not come back yet.
  final bool waiting;
  final VoidCallback? onOpen;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final c = RaselnaChatColors.of(context);
    final (icon, body) = switch (prompt.reason) {
      HandoffReason.catalog => (
        Icons.storefront_outlined,
        strings.handoffCatalog,
      ),
      HandoffReason.cart => (Icons.shopping_bag_outlined, strings.handoffCart),
      HandoffReason.form => (Icons.edit_note_outlined, strings.handoffForm),
      HandoffReason.secret => (Icons.lock_outline, strings.handoffSecret),
      HandoffReason.unknown => (Icons.open_in_new, strings.handoffOther),
    };
    final count = prompt.count;
    return ChatCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: c.tint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: c.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.handoffTitle,
                        style: c.style(
                          size: 15,
                          weight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                      if (count != null && count > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            strings.products.replaceAll('{n}', '$count'),
                            style: c.style(
                              size: 13,
                              weight: FontWeight.w500,
                              color: c.accent,
                            ),
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        waiting ? strings.handoffWaiting : body,
                        style: c.style(
                          size: 13.5,
                          color: c.mutedText,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: c.border),
          Padding(
            padding: const EdgeInsets.all(10),
            child:
                waiting
                    ? ReplyChip(
                      label: strings.handoffBack,
                      icon: Icons.refresh,
                      onTap: onBack,
                    )
                    : ReplyChip(
                      label: prompt.label ?? strings.handoffOpen,
                      icon: Icons.open_in_new,
                      filled: true,
                      onTap: onOpen,
                    ),
          ),
        ],
      ),
    );
  }
}

/// The conversation waits: its number, to come back to it later.
class PausedCard extends StatefulWidget {
  const PausedCard({super.key, required this.code, required this.strings});

  final String code;
  final RaselnaStrings strings;

  @override
  State<PausedCard> createState() => _PausedCardState();
}

class _PausedCardState extends State<PausedCard> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final c = RaselnaChatColors.of(context);
    final s = widget.strings;
    return ChatCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(s.pausedTitle, style: c.style(size: 13, color: c.mutedText)),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Directionality(
                textDirection: TextDirection.ltr,
                child: SelectableText(
                  widget.code,
                  style: c.style(
                    size: 22,
                    weight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed:
                    widget.code.isEmpty
                        ? null
                        : () async {
                          await Clipboard.setData(
                            ClipboardData(text: widget.code),
                          );
                          if (mounted) setState(() => _copied = true);
                        },
                style: TextButton.styleFrom(
                  foregroundColor: c.accent,
                  minimumSize: const Size(48, 44),
                ),
                icon: Icon(
                  _copied ? Icons.check : Icons.copy_rounded,
                  size: 18,
                ),
                label: Text(
                  _copied ? s.copied : s.copy,
                  style: c.style(
                    size: 14,
                    weight: FontWeight.w500,
                    color: c.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(s.pausedHint, style: c.style(size: 13.5, color: c.mutedText)),
        ],
      ),
    );
  }
}
