import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

/// The bar at the top: the business's logo (or initial), the bot's name
/// and "online" / "typing…".
class ChatHeader extends StatelessWidget {
  const ChatHeader({
    super.key,
    required this.config,
    required this.status,
    this.onClose,
    this.closeLabel,
  });

  final ChatConfig? config;
  final String status;
  final VoidCallback? onClose;
  final String? closeLabel;

  @override
  Widget build(BuildContext context) {
    final c = RaselnaChatColors.of(context);
    final cfg = config;
    final logo = cfg?.logoUrl;
    return Material(
      color: c.primary,
      child: SafeArea(
        bottom: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 16, 8),
            child: Row(
              children: [
                if (onClose != null)
                  IconButton(
                    onPressed: onClose,
                    tooltip: closeLabel,
                    color: c.onPrimary,
                    icon: const Icon(Icons.arrow_back),
                  )
                else
                  const SizedBox(width: 8),
                const SizedBox(width: 2),
                ExcludeSemantics(
                  child: Container(
                    width: 42,
                    height: 42,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: c.onPrimary.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: c.onPrimary.withValues(alpha: 0.28),
                      ),
                    ),
                    alignment: Alignment.center,
                    child:
                        logo != null
                            ? Image.network(
                              logo,
                              width: 42,
                              height: 42,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (_, _, _) => _Initial(cfg!.avatarInitial, c),
                            )
                            : _Initial(cfg?.avatarInitial ?? '', c),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          cfg?.botName ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: c.style(
                            size: 17,
                            weight: FontWeight.w700,
                            color: c.onPrimary,
                            height: 1.3,
                          ),
                        ),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            status,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: c.style(
                              size: 13,
                              color: c.onPrimary.withValues(alpha: 0.85),
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Initial extends StatelessWidget {
  const _Initial(this.letter, this.c);

  final String letter;
  final RaselnaChatColors c;

  @override
  Widget build(BuildContext context) => Text(
    letter,
    style: c.style(
      size: 19,
      weight: FontWeight.w700,
      color: c.onPrimary,
      height: 1,
    ),
  );
}

/// The faint eight-point star lattice behind the messages (a nod to the
/// Levantine tile, drawn in the tenant's accent at a few percent).
class ChatPattern extends CustomPainter {
  ChatPattern(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
    const step = 56.0;
    const r = 9.0;
    for (var y = step / 2; y < size.height + step; y += step) {
      final row = ((y - step / 2) / step).round();
      for (
        var x = (row.isOdd ? step : step / 2);
        x < size.width + step;
        x += step
      ) {
        canvas.drawPath(_star(Offset(x, y), r), paint);
      }
    }
  }

  static Path _star(Offset c, double r) {
    final p = Path();
    for (var i = 0; i < 16; i++) {
      final a = i * math.pi / 8 - math.pi / 2;
      final rr = i.isEven ? r : r * 0.55;
      final pt = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
      if (i == 0) {
        p.moveTo(pt.dx, pt.dy);
      } else {
        p.lineTo(pt.dx, pt.dy);
      }
    }
    return p..close();
  }

  @override
  bool shouldRepaint(ChatPattern oldDelegate) => oldDelegate.color != color;
}
