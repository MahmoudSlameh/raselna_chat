import 'package:flutter/material.dart';

import '../controller.dart';
import '../models.dart';
import '../strings.dart';
import '../theme.dart';

/// One message bubble. Bot bubbles sit at the reading start (right in
/// Arabic), customer bubbles at the end, in the business's colour.
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.entry,
    required this.botName,
    required this.strings,
    this.lastInGroup = true,
    this.onRetry,
  });

  final ChatEntry entry;
  final String botName;
  final RaselnaStrings strings;
  final bool lastInGroup;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final c = RaselnaChatColors.of(context);
    if (entry.side == ChatSide.system) {
      return SystemLine(text: entry.text ?? '');
    }

    final mine = entry.side == ChatSide.customer;
    final r = Radius.circular(c.radius);
    const tail = Radius.circular(5);
    final radius = BorderRadiusDirectional.only(
      topStart: r,
      topEnd: r,
      bottomStart: !mine && lastInGroup ? tail : r,
      bottomEnd: mine && lastInGroup ? tail : r,
    );
    final fg = mine ? c.onPrimary : c.text;
    final meta = mine ? c.onPrimary.withValues(alpha: 0.78) : c.mutedText;

    final children = <Widget>[
      if (entry.imageUrl != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(c.radius - 6),
            child: Image.network(
              entry.imageUrl!,
              semanticLabel: entry.imageAlt,
              fit: BoxFit.cover,
              errorBuilder:
                  (_, _, _) => Container(
                    height: 120,
                    color: c.border,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: c.mutedText,
                    ),
                  ),
            ),
          ),
        ),
      if (entry.text != null && entry.text!.isNotEmpty)
        Text(entry.text!, style: c.style(color: fg)),
      if (entry.card != null) ...[
        const SizedBox(height: 8),
        StatusCardView(card: entry.card!),
      ],
      const SizedBox(height: 2),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _hhmm(entry.at),
            style: c.style(size: 11, color: meta, height: 1.2),
          ),
          if (mine) ...[
            const SizedBox(width: 4),
            _DeliveryIcon(
              delivery: entry.delivery,
              color: meta,
              danger: c.danger,
            ),
          ],
        ],
      ),
    ];

    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.8,
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 6),
      decoration: BoxDecoration(
        color: mine ? c.primary : c.surface,
        borderRadius: radius,
        border: mine ? null : Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ...children.take(children.length - 1),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: children.last,
          ),
        ],
      ),
    );

    final status = switch (entry.delivery) {
      Delivery.queued => strings.queued,
      Delivery.failed => strings.retry,
      _ => '',
    };
    final label =
        mine
            ? '${strings.you}: ${entry.text ?? ''}${status.isEmpty ? '' : '، $status'}'
            : '${strings.botSaid.replaceAll('{bot}', botName)}: ${entry.text ?? entry.imageAlt ?? ''}'
                '${entry.card == null ? '' : '. ${entry.card!.title}: ${entry.card!.status}'}';

    return Padding(
      padding: EdgeInsets.only(top: 2, bottom: lastInGroup ? 8 : 2),
      child: Column(
        crossAxisAlignment:
            mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Semantics(
            container: true,
            label: label,
            child: ExcludeSemantics(child: bubble),
          ),
          if (mine && entry.delivery == Delivery.failed && onRetry != null)
            TextButton.icon(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: c.danger,
                minimumSize: const Size(48, 40),
              ),
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(
                strings.retry,
                style: c.style(size: 13, color: c.danger),
              ),
            ),
        ],
      ),
    );
  }

  static String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

class _DeliveryIcon extends StatelessWidget {
  const _DeliveryIcon({
    required this.delivery,
    required this.color,
    required this.danger,
  });

  final Delivery delivery;
  final Color color;
  final Color danger;

  @override
  Widget build(BuildContext context) => switch (delivery) {
    Delivery.sending ||
    Delivery.queued => Icon(Icons.schedule, size: 14, color: color),
    Delivery.sent => Icon(Icons.done_all, size: 15, color: color),
    Delivery.failed => Icon(Icons.error_outline, size: 15, color: danger),
  };
}

/// The status card on a bot message (an order's state, a booking).
class StatusCardView extends StatelessWidget {
  const StatusCardView({super.key, required this.card});

  final StatusCard card;

  @override
  Widget build(BuildContext context) {
    final c = RaselnaChatColors.of(context);
    final tone = switch (card.tone) {
      StatusTone.success => c.success,
      StatusTone.warning => c.warning,
      StatusTone.danger => c.danger,
      StatusTone.neutral => c.accent,
    };
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: c.tint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(card.title, style: c.style(size: 14, weight: FontWeight.w700)),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  card.status,
                  style: c.style(
                    size: 14,
                    weight: FontWeight.w500,
                    color: tone,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A centred grey line (system note, date divider).
class SystemLine extends StatelessWidget {
  const SystemLine({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = RaselnaChatColors.of(context);
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: c.surface.withValues(alpha: c.isDark ? 0.9 : 0.85),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: c.border),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: c.style(size: 12, color: c.mutedText, height: 1.3),
        ),
      ),
    );
  }
}

/// Three dots in a bot bubble while the bot "types".
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key, required this.label});

  final String label;

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _anim.stop();
    } else if (!_anim.isAnimating) {
      _anim.repeat();
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = RaselnaChatColors.of(context);
    return Semantics(
      label: widget.label,
      liveRegion: true,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: c.border),
            borderRadius: BorderRadiusDirectional.only(
              topStart: Radius.circular(c.radius),
              topEnd: Radius.circular(c.radius),
              bottomEnd: Radius.circular(c.radius),
              bottomStart: const Radius.circular(5),
            ),
          ),
          child: AnimatedBuilder(
            animation: _anim,
            builder:
                (context, _) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2.5),
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c.mutedText.withValues(alpha: _dot(i)),
                        ),
                      ),
                  ],
                ),
          ),
        ),
      ),
    );
  }

  double _dot(int i) {
    final t = (_anim.value * 3 - i) % 3;
    return t < 1
        ? 0.35 + 0.6 * (1 - (t - 0.5).abs() * 2).clamp(0.0, 1.0).toDouble()
        : 0.35;
  }
}
