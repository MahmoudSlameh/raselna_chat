// Native rich steps (0.2.0): catalogue, product sheet, finder results, cart,
// checkout form and price range. Everything the customer sees about products
// and prices comes from the server as display text; the app only sends
// actions with the server's opaque ids and a quantity, never a price.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controller.dart';
import '../models.dart';
import '../strings.dart';
import '../theme.dart';
import '../validators.dart';
import 'prompts.dart';

/// `2`, `0.25`, `1.5`: a quantity as the customer reads it.
String qtyText(num n) {
  final r = (n * 100).round() / 100;
  return r == r.roundToDouble() ? r.toInt().toString() : r.toString();
}

/// Opens a tall sheet inside the chat's colours and direction.
Future<T?> showChatSheet<T>(
  BuildContext context, {
  required RaselnaChatColors colors,
  required TextDirection direction,
  required WidgetBuilder builder,
  double heightFactor = 0.9,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: colors.surface,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder:
        (context) => RaselnaChatColorsScope(
          colors: colors,
          child: Directionality(
            textDirection: direction,
            child: Padding(
              // Keep fields above the keyboard.
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * heightFactor,
                ),
                child: Builder(builder: builder),
              ),
            ),
          ),
        ),
  );
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title, required this.closeLabel});

  final String title;
  final String closeLabel;

  @override
  Widget build(BuildContext context) {
    final c = RaselnaChatColors.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: c.style(size: 17, weight: FontWeight.w700),
              ),
            ),
          ),
          IconButton(
            tooltip: closeLabel,
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(Icons.close, color: c.mutedText),
          ),
        ],
      ),
    );
  }
}

/// A product picture, or a soft tile with the name's first letter.
class ProductThumb extends StatelessWidget {
  const ProductThumb({
    super.key,
    required this.url,
    required this.name,
    this.size = 64,
    this.radius = 12,
  });

  final String? url;
  final String name;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = RaselnaChatColors.of(context);
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: c.tint,
      child: Text(
        name.isEmpty ? '•' : String.fromCharCode(name.runes.first),
        style: c.style(
          size: size * 0.38,
          weight: FontWeight.w700,
          color: c.onTint,
          height: 1,
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child:
          url == null
              ? fallback
              : Image.network(
                url!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => fallback,
              ),
    );
  }
}

/// − qty + (the minus becomes a bin at the minimum when [canRemove]).
class QtyStepper extends StatelessWidget {
  const QtyStepper({
    super.key,
    required this.value,
    required this.step,
    required this.max,
    required this.label,
    required this.strings,
    required this.onChanged,
    this.min = 0,
    this.unit,
    this.canRemove = false,
  });

  final num value;
  final num step;
  final num min;
  final num max;
  final String label;
  final String? unit;
  final RaselnaShopStrings strings;
  final bool canRemove;

  /// Null = disabled.
  final ValueChanged<num>? onChanged;

  num _round(num v) => (v * 1000).round() / 1000;

  @override
  Widget build(BuildContext context) {
    final c = RaselnaChatColors.of(context);
    final down = _round(value - step);
    final up = _round(value + step);
    final removes = canRemove && down < (step < 1 ? step : 1) && down <= min;
    final canDown =
        onChanged != null && (removes || down >= (min == 0 ? step : min));
    final canUp = onChanged != null && up <= max;

    Widget button(IconData icon, String tip, VoidCallback? onTap) => Semantics(
      button: true,
      label: '$tip $label',
      child: Material(
        color: c.tint,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap:
              onTap == null
                  ? null
                  : () {
                    HapticFeedback.selectionClick();
                    onTap();
                  },
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              icon,
              size: 20,
              color: onTap == null ? c.mutedText : c.onTint,
            ),
          ),
        ),
      ),
    );

    return Semantics(
      container: true,
      label: '${strings.quantity}: $label',
      value: '${qtyText(value)}${unit == null ? '' : ' $unit'}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(
            removes ? Icons.delete_outline : Icons.remove,
            removes ? strings.remove : strings.decrease,
            canDown ? () => onChanged!(removes ? 0 : down) : null,
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 52),
            child: ExcludeSemantics(
              child: Text(
                unit == null ? qtyText(value) : '${qtyText(value)} $unit',
                textAlign: TextAlign.center,
                style: c.style(size: 15, weight: FontWeight.w700, height: 1.2),
              ),
            ),
          ),
          button(
            Icons.add,
            strings.increase,
            canUp ? () => onChanged!(up) : null,
          ),
        ],
      ),
    );
  }
}

/// A full-width primary or secondary button for the bars and sheets.
class ShopButton extends StatelessWidget {
  const ShopButton({
    super.key,
    required this.label,
    required this.onTap,
    this.primary = true,
    this.icon,
  });

  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final IconData? icon;

  @override
  Widget build(BuildContext context) =>
      ReplyChip(label: label, onTap: onTap, filled: primary, icon: icon);
}

// --- Catalogue ----------------------------------------------------------------

/// The catalogue card in the conversation.
class CatalogCard extends StatelessWidget {
  const CatalogCard({
    super.key,
    required this.prompt,
    required this.strings,
    required this.onBrowse,
  });

  final ProductListPrompt prompt;
  final RaselnaStrings strings;
  final VoidCallback? onBrowse;

  @override
  Widget build(BuildContext context) {
    final c = RaselnaChatColors.of(context);
    final s = strings.shop;
    final preview = prompt.products.where((p) => p.available).take(4).toList();
    return ChatCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: c.tint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.storefront_outlined, color: c.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.menu,
                        style: c.style(
                          size: 16,
                          weight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                      Text(
                        strings.products.replaceAll(
                          '{n}',
                          '${prompt.products.length}',
                        ),
                        style: c.style(
                          size: 13,
                          color: c.mutedText,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (preview.isNotEmpty)
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: preview.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder:
                    (context, i) => Semantics(
                      label: preview[i].name,
                      child: ProductThumb(
                        url: preview[i].picture,
                        name: preview[i].name,
                        size: 88,
                      ),
                    ),
              ),
            ),
          if (prompt.categories.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Text(
                prompt.categories.map((x) => x.name).join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: c.style(size: 13, color: c.mutedText),
              ),
            ),
          if (prompt.notice != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Text(
                prompt.notice!,
                style: c.style(size: 13, color: c.warning),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: ShopButton(
              label: s.browse,
              icon: Icons.menu_book_outlined,
              onTap: onBrowse,
            ),
          ),
        ],
      ),
    );
  }
}

/// Under the conversation while the catalogue is open: cart count, total
/// and "go to cart".
class CatalogBar extends StatelessWidget {
  const CatalogBar({
    super.key,
    required this.prompt,
    required this.strings,
    required this.onBrowse,
    required this.onDone,
  });

  final ProductListPrompt prompt;
  final RaselnaStrings strings;
  final VoidCallback? onBrowse;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final c = RaselnaChatColors.of(context);
    final s = strings.shop;
    final n = prompt.cartCount;
    return Row(
      children: [
        Expanded(
          child: Semantics(
            button: true,
            label: '${s.count(n)} ${prompt.cartTotal ?? ''}',
            child: InkWell(
              onTap: onBrowse,
              borderRadius: BorderRadius.circular(12),
              child: ExcludeSemantics(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Badge(
                        label: Text('$n'),
                        isLabelVisible: n > 0,
                        backgroundColor: c.primary,
                        textColor: c.onPrimary,
                        child: Icon(
                          Icons.shopping_basket_outlined,
                          color: c.accent,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              s.count(n),
                              style: c.style(
                                size: 14,
                                weight: FontWeight.w700,
                                height: 1.3,
                              ),
                            ),
                            if (n > 0 && prompt.cartTotal != null)
                              Text(
                                prompt.cartTotal!,
                                style: c.style(
                                  size: 13,
                                  color: c.mutedText,
                                  height: 1.3,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: ShopButton(
            label: prompt.doneLabel ?? s.cart,
            onTap: n == 0 ? null : onDone,
          ),
        ),
      ],
    );
  }
}

/// The catalogue sheet: search, category tabs and product rows. It follows
/// the controller, so it stays open (and updates) between two adds.
class CatalogSheet extends StatefulWidget {
  const CatalogSheet({
    super.key,
    required this.controller,
    required this.strings,
    required this.onOpenProduct,
  });

  final RaselnaChatController controller;
  final RaselnaStrings strings;
  final void Function(BuildContext context, Product product) onOpenProduct;

  @override
  State<CatalogSheet> createState() => _CatalogSheetState();
}

class _CatalogSheetState extends State<CatalogSheet> {
  String? _cat;
  String _query = '';
  ProductListPrompt? _last;

  @override
  Widget build(BuildContext context) {
    final c = RaselnaChatColors.of(context);
    final s = widget.strings.shop;
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final ctl = widget.controller;
        final rich = ctl.richPrompt;
        if (rich is ProductListPrompt) _last = rich;
        final idle = !ctl.isBusy && ctl.queuedCount == 0;
        // The step moved on (cart, checkout…): close.
        if (rich is! ProductListPrompt &&
            idle &&
            ctl.phase == ChatPhase.ready) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) Navigator.of(context).maybePop();
          });
        }
        final prompt = _last;
        if (prompt == null) return const SizedBox.shrink();
        final q = _query.trim().toLowerCase();
        final shown =
            prompt.products
                .where((p) => _cat == null || p.category == _cat)
                .where(
                  (p) =>
                      q.isEmpty ||
                      p.name.toLowerCase().contains(q) ||
                      (p.description ?? '').toLowerCase().contains(q),
                )
                .toList();

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SheetHeader(title: s.menu, closeLabel: s.close),
            if (prompt.products.length > 6)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  textInputAction: TextInputAction.search,
                  style: c.style(size: 16, height: 1.3),
                  decoration: InputDecoration(
                    hintText: s.search,
                    hintStyle: c.style(size: 15, color: c.mutedText),
                    prefixIcon: Icon(Icons.search, color: c.mutedText),
                    filled: true,
                    fillColor: c.background,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            if (prompt.categories.isNotEmpty)
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  children: [
                    _Tab(
                      label: s.all,
                      selected: _cat == null,
                      onTap: () => setState(() => _cat = null),
                    ),
                    for (final cat in prompt.categories)
                      _Tab(
                        label: cat.name,
                        selected: _cat == cat.id,
                        onTap: () => setState(() => _cat = cat.id),
                      ),
                  ],
                ),
              ),
            Flexible(
              child:
                  shown.isEmpty
                      ? Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          q.isEmpty
                              ? (prompt.emptyText ?? s.noProducts)
                              : s.noMatch,
                          textAlign: TextAlign.center,
                          style: c.style(color: c.mutedText),
                        ),
                      )
                      : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                        itemCount: shown.length,
                        separatorBuilder:
                            (_, _) => Divider(height: 1, color: c.border),
                        itemBuilder:
                            (context, i) => _ProductRow(
                              product: shown[i],
                              strings: s,
                              onTap:
                                  () => widget.onOpenProduct(context, shown[i]),
                            ),
                      ),
            ),
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: c.border)),
              ),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: CatalogBar(
                prompt: prompt,
                strings: widget.strings,
                onBrowse: null,
                onDone:
                    idle
                        ? () => ctl.act(
                          const ActionReply('done'),
                          echo: prompt.doneLabel ?? s.cart,
                        )
                        : null,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = RaselnaChatColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? c.primary : c.tint,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                label,
                style: c.style(
                  size: 14,
                  weight: FontWeight.w500,
                  color: selected ? c.onPrimary : c.onTint,
                  height: 1.3,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.product,
    required this.strings,
    required this.onTap,
  });

  final Product product;
  final RaselnaShopStrings strings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = RaselnaChatColors.of(context);
    final p = product;
    return Semantics(
      button: true,
      enabled: p.available,
      label: [
        p.name,
        if (p.price != null)
          '${p.price}${p.unit == null ? '' : ' / ${p.unit}'}',
        if (!p.available) strings.soldOut,
      ].join('، '),
      child: InkWell(
        onTap: p.available ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: ExcludeSemantics(
          child: Opacity(
            opacity: p.available ? 1 : 0.55,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Row(
                children: [
                  ProductThumb(url: p.picture, name: p.name),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          style: c.style(
                            size: 15,
                            weight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                        if (p.description != null)
                          Text(
                            p.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: c.style(
                              size: 13,
                              color: c.mutedText,
                              height: 1.4,
                            ),
                          ),
                        if (p.price != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: p.price,
                                    style: c.style(
                                      size: 14,
                                      weight: FontWeight.w700,
                                      color: c.accent,
                                    ),
                                  ),
                                  if (p.unit != null)
                                    TextSpan(
                                      text: ' / ${p.unit}',
                                      style: c.style(
                                        size: 12,
                                        color: c.mutedText,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  p.available
                      ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: c.tint,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: c.accent.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          strings.add,
                          style: c.style(
                            size: 13.5,
                            weight: FontWeight.w700,
                            color: c.onTint,
                            height: 1.2,
                          ),
                        ),
                      )
                      : Text(
                        strings.soldOut,
                        style: c.style(size: 13, color: c.danger),
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

/// What the product sheet returns: a quantity and one choice id per group.
class ProductPick {
  const ProductPick(this.qty, this.options);

  final num qty;
  final List<String> options;
}

/// One product: picture, options (one per group) and quantity.
class ProductSheet extends StatefulWidget {
  const ProductSheet({
    super.key,
    required this.product,
    required this.strings,
    this.enabled = true,
  });

  final Product product;
  final RaselnaShopStrings strings;
  final bool enabled;

  @override
  State<ProductSheet> createState() => _ProductSheetState();
}

class _ProductSheetState extends State<ProductSheet> {
  late num _qty = widget.product.step < 1 ? 1 : widget.product.step;
  final Map<String, String> _picked = {};

  @override
  Widget build(BuildContext context) {
    final c = RaselnaChatColors.of(context);
    final s = widget.strings;
    final p = widget.product;
    final ready =
        p.available &&
        p.groups.every((g) => !g.required || _picked.containsKey(g.name));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SheetHeader(title: p.name, closeLabel: s.close),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            children: [
              if (p.picture != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        p.picture!,
                        fit: BoxFit.cover,
                        semanticLabel: p.name,
                        errorBuilder: (_, _, _) => Container(color: c.tint),
                      ),
                    ),
                  ),
                ),
              if (p.description != null)
                Text(
                  p.description!,
                  style: c.style(size: 14.5, color: c.mutedText),
                ),
              if (p.price != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    p.unit == null ? p.price! : '${p.price} / ${p.unit}',
                    style: c.style(
                      size: 17,
                      weight: FontWeight.w700,
                      color: c.accent,
                    ),
                  ),
                ),
              for (final g in p.groups) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        g.name,
                        style: c.style(size: 15, weight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      g.required ? s.required : s.optional,
                      style: c.style(
                        size: 12,
                        color: g.required ? c.accent : c.mutedText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                for (final ch in g.choices)
                  _ChoiceRow(
                    label: ch.name,
                    trailing: ch.price,
                    selected: _picked[g.name] == ch.id,
                    onTap:
                        () => setState(() {
                          if (_picked[g.name] == ch.id && !g.required) {
                            _picked.remove(g.name);
                          } else {
                            _picked[g.name] = ch.id;
                          }
                        }),
                  ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      s.quantity,
                      style: c.style(size: 15, weight: FontWeight.w700),
                    ),
                  ),
                  QtyStepper(
                    value: _qty,
                    step: p.step,
                    min: p.step < 1 ? p.step : 1,
                    max: p.max,
                    unit: p.unit,
                    label: p.name,
                    strings: s,
                    onChanged: (v) => setState(() => _qty = v),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: c.border)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: ShopButton(
            label: p.available ? s.addToCart : s.soldOut,
            icon: Icons.add_shopping_cart,
            onTap:
                ready && widget.enabled
                    ? () => Navigator.of(
                      context,
                    ).pop(ProductPick(_qty, _picked.values.toList()))
                    : null,
          ),
        ),
      ],
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailing,
    this.hint,
  });

  final String label;
  final String? trailing;
  final String? hint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = RaselnaChatColors.of(context);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      label: [
        label,
        if (hint != null) hint!,
        if (trailing != null) trailing!,
      ].join('، '),
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 3),
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? c.tint : null,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? c.accent : c.border),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 20,
                  color: selected ? c.accent : c.mutedText,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: c.style(size: 14.5, height: 1.35)),
                      if (hint != null)
                        Text(
                          hint!,
                          style: c.style(
                            size: 12.5,
                            color: c.mutedText,
                            height: 1.3,
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailing != null)
                  Text(trailing!, style: c.style(size: 13, color: c.mutedText)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- Finder results (mode = pick) --------------------------------------------

/// A horizontal strip of result cards with "details" and "I want this".
class PickResults extends StatelessWidget {
  const PickResults({
    super.key,
    required this.prompt,
    required this.strings,
    required this.onDetails,
    required this.onSelect,
  });

  final ProductListPrompt prompt;
  final RaselnaStrings strings;
  final ValueChanged<Product> onDetails;
  final ValueChanged<Product>? onSelect;

  @override
  Widget build(BuildContext context) {
    final c = RaselnaChatColors.of(context);
    final s = strings.shop;
    final n = prompt.total ?? prompt.products.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 4, bottom: 6),
            child: Text(
              n == 1 ? s.oneItem : s.items.replaceAll('{n}', '$n'),
              style: c.style(
                size: 13,
                weight: FontWeight.w500,
                color: c.mutedText,
              ),
            ),
          ),
          if (prompt.products.isEmpty)
            ChatCard(
              child: Text(
                prompt.emptyText ?? s.noProducts,
                style: c.style(color: c.mutedText),
              ),
            )
          else
            SizedBox(
              height: 330,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: prompt.products.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder:
                    (context, i) => _PickCard(
                      product: prompt.products[i],
                      selectLabel: prompt.selectLabel ?? s.choose,
                      detailsLabel: prompt.detailsLabel ?? s.details,
                      onDetails: () => onDetails(prompt.products[i]),
                      onSelect:
                          onSelect == null
                              ? null
                              : () => onSelect!(prompt.products[i]),
                    ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PickCard extends StatelessWidget {
  const _PickCard({
    required this.product,
    required this.selectLabel,
    required this.detailsLabel,
    required this.onDetails,
    required this.onSelect,
  });

  final Product product;
  final String selectLabel;
  final String detailsLabel;
  final VoidCallback onDetails;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final c = RaselnaChatColors.of(context);
    final p = product;
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(c.radius),
        border: Border.all(color: c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 120,
            child: ColoredBox(
              color: c.tint,
              child:
                  p.picture == null
                      ? Container(
                        color: c.tint,
                        child: Icon(
                          Icons.image_outlined,
                          color: c.accent,
                          size: 36,
                        ),
                      )
                      : Image.network(
                        p.picture!,
                        fit: BoxFit.contain,
                        semanticLabel: p.name,
                        errorBuilder: (_, _, _) => Container(color: c.tint),
                      ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (p.categoryName != null)
                    Text(
                      p.categoryName!,
                      style: c.style(size: 12, color: c.mutedText, height: 1.3),
                    ),
                  Text(
                    p.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: c.style(
                      size: 15,
                      weight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  if (p.price != null)
                    Text(
                      p.price!,
                      style: c.style(
                        size: 14,
                        weight: FontWeight.w700,
                        color: c.accent,
                        height: 1.4,
                      ),
                    ),
                  if (p.priceHint != null)
                    Text(
                      p.priceHint!,
                      style: c.style(size: 12, color: c.mutedText, height: 1.3),
                    ),
                  for (final a in p.attributes.take(2))
                    Text(
                      '${a.label}: ${a.value}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: c.style(
                        size: 12.5,
                        color: c.mutedText,
                        height: 1.4,
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: TextButton(
                    onPressed: onDetails,
                    style: TextButton.styleFrom(
                      foregroundColor: c.accent,
                      minimumSize: const Size(48, 44),
                    ),
                    child: Text(
                      detailsLabel,
                      style: c.style(
                        size: 13.5,
                        weight: FontWeight.w700,
                        color: c.accent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: ReplyChip(
                    label: selectLabel,
                    filled: true,
                    onTap: onSelect,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A finder result in full: pictures, code, details.
class PickDetails extends StatefulWidget {
  const PickDetails({
    super.key,
    required this.product,
    required this.strings,
    required this.selectLabel,
    required this.enabled,
  });

  final Product product;
  final RaselnaShopStrings strings;
  final String selectLabel;
  final bool enabled;

  @override
  State<PickDetails> createState() => _PickDetailsState();
}

class _PickDetailsState extends State<PickDetails> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final c = RaselnaChatColors.of(context);
    final p = widget.product;
    final s = widget.strings;
    final pictures = [
      if (p.imageUrl != null && !p.images.contains(p.imageUrl)) p.imageUrl!,
      ...p.images,
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SheetHeader(title: p.name, closeLabel: s.close),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            children: [
              if (pictures.isNotEmpty) ...[
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: PageView.builder(
                      itemCount: pictures.length,
                      onPageChanged: (i) => setState(() => _page = i),
                      itemBuilder:
                          (context, i) => Image.network(
                            pictures[i],
                            fit: BoxFit.cover,
                            semanticLabel: s.picture
                                .replaceAll('{i}', '${i + 1}')
                                .replaceAll('{n}', '${pictures.length}'),
                            errorBuilder: (_, _, _) => Container(color: c.tint),
                          ),
                    ),
                  ),
                ),
                if (pictures.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < pictures.length; i++)
                          Container(
                            width: 7,
                            height: 7,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i == _page ? c.accent : c.border,
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
              ],
              if (p.price != null)
                Text(
                  p.price!,
                  style: c.style(
                    size: 18,
                    weight: FontWeight.w700,
                    color: c.accent,
                  ),
                ),
              if (p.priceHint != null)
                Text(
                  p.priceHint!,
                  style: c.style(size: 13, color: c.mutedText),
                ),
              if (p.code != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${s.code}: ${p.code}',
                    style: c.style(size: 13, color: c.mutedText),
                  ),
                ),
              if (p.description != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(p.description!, style: c.style(size: 14.5)),
                ),
              const SizedBox(height: 8),
              for (final d in [...p.attributes, ...p.details])
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: c.border)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          d.label,
                          style: c.style(size: 13.5, color: c.mutedText),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          d.value,
                          style: c.style(size: 13.5, weight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: c.border)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: ShopButton(
            label: widget.selectLabel,
            onTap:
                widget.enabled ? () => Navigator.of(context).pop(true) : null,
          ),
        ),
      ],
    );
  }
}

// --- Cart ---------------------------------------------------------------------

/// The cart in the conversation: lines with steppers and the server's totals.
class CartCard extends StatelessWidget {
  const CartCard({
    super.key,
    required this.prompt,
    required this.strings,
    required this.onQty,
  });

  final CartPrompt prompt;
  final RaselnaStrings strings;

  /// (line, new quantity); 0 removes. Null = disabled.
  final void Function(CartLine line, num qty)? onQty;

  @override
  Widget build(BuildContext context) {
    final c = RaselnaChatColors.of(context);
    final s = strings.shop;
    return ChatCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.shopping_basket_outlined, color: c.accent, size: 22),
              const SizedBox(width: 8),
              Semantics(
                header: true,
                child: Text(
                  s.cart,
                  style: c.style(size: 16, weight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (prompt.lines.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                prompt.emptyText ?? s.cartEmpty,
                style: c.style(color: c.mutedText),
              ),
            ),
          for (final l in prompt.lines)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: c.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.name,
                              style: c.style(
                                size: 15,
                                weight: FontWeight.w700,
                                height: 1.35,
                              ),
                            ),
                            if (l.options != null)
                              Text(
                                l.options!,
                                style: c.style(
                                  size: 12.5,
                                  color: c.mutedText,
                                  height: 1.35,
                                ),
                              ),
                            if (l.unitPrice != null)
                              Text(
                                l.unit == null
                                    ? l.unitPrice!
                                    : '${l.unitPrice} / ${l.unit}',
                                style: c.style(
                                  size: 12.5,
                                  color: c.mutedText,
                                  height: 1.35,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (l.total != null)
                        Text(
                          l.total!,
                          style: c.style(size: 14.5, weight: FontWeight.w700),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: QtyStepper(
                      value: l.qty,
                      step: l.step,
                      max: l.max,
                      unit: l.unit,
                      label: l.name,
                      strings: s,
                      canRemove: true,
                      onChanged: onQty == null ? null : (q) => onQty!(l, q),
                    ),
                  ),
                ],
              ),
            ),
          if (prompt.subtotal != null && prompt.lines.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      s.subtotal,
                      style: c.style(size: 15, weight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    prompt.subtotal!,
                    style: c.style(
                      size: 16,
                      weight: FontWeight.w700,
                      color: c.accent,
                    ),
                  ),
                ],
              ),
            ),
          if (prompt.notice != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                prompt.notice!,
                style: c.style(size: 13, color: c.warning),
              ),
            ),
        ],
      ),
    );
  }
}

// --- Forms ----------------------------------------------------------------------

/// The checkout card in the conversation: summary and "fill in".
class FormCard extends StatefulWidget {
  const FormCard({
    super.key,
    required this.prompt,
    required this.strings,
    required this.onOpen,
    this.autoOpen = true,
  });

  final FormPrompt prompt;
  final RaselnaStrings strings;
  final VoidCallback? onOpen;

  /// Open the sheet by itself once per new form (like the web chat).
  final bool autoOpen;

  @override
  State<FormCard> createState() => _FormCardState();
}

class _FormCardState extends State<FormCard> {
  static final _opened = Expando<bool>();

  @override
  void initState() {
    super.initState();
    _maybeOpen();
  }

  @override
  void didUpdateWidget(FormCard old) {
    super.didUpdateWidget(old);
    if (!identical(old.prompt, widget.prompt)) _maybeOpen();
  }

  void _maybeOpen() {
    if (!widget.autoOpen ||
        widget.onOpen == null ||
        _opened[widget.prompt] == true) {
      return;
    }
    _opened[widget.prompt] = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onOpen?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = RaselnaChatColors.of(context);
    final s = widget.strings.shop;
    final p = widget.prompt;
    return ChatCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.assignment_outlined, color: c.accent, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  p.title ?? s.form,
                  style: c.style(size: 16, weight: FontWeight.w700),
                ),
              ),
            ],
          ),
          for (final row in p.summary)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row.label,
                      style: c.style(size: 13.5, color: c.mutedText),
                    ),
                  ),
                  Text(
                    row.value,
                    style: c.style(size: 13.5, weight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          if (p.hasErrors)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                p.error ?? s.fieldRequired,
                style: c.style(size: 13, color: c.danger),
              ),
            ),
          const SizedBox(height: 10),
          ShopButton(
            label: p.openLabel ?? s.fillForm,
            icon: Icons.edit_note,
            onTap: widget.onOpen,
          ),
        ],
      ),
    );
  }
}

/// The checkout form: every field on one sheet, with `show_if`, local
/// checks (required, phone) and the server's messages per field.
class FormSheet extends StatefulWidget {
  const FormSheet({super.key, required this.prompt, required this.strings});

  final FormPrompt prompt;
  final RaselnaStrings strings;

  @override
  State<FormSheet> createState() => _FormSheetState();
}

class _FormSheetState extends State<FormSheet> {
  late final Map<String, String> _values = {
    for (final f in widget.prompt.fields) f.name: f.value ?? '',
  };
  final Map<String, String> _errors = {};
  final Set<String> _edited = {};

  bool _visible(FormFieldSpec f) =>
      f.showIfField == null || _values[f.showIfField] == f.showIfValue;

  void _submit() {
    final s = widget.strings;
    _errors.clear();
    final visible = widget.prompt.fields.where(_visible).toList();
    for (final f in visible) {
      final v = (_values[f.name] ?? '').trim();
      if (f.required && v.isEmpty) {
        _errors[f.name] = s.shop.fieldRequired;
      } else if (f.type == FormFieldKind.phone && v.isNotEmpty) {
        final e = validateAnswer(InputKind.phone, v, s);
        if (e != null) _errors[f.name] = e;
      }
    }
    setState(() {});
    if (_errors.isNotEmpty) return;
    Navigator.of(context).pop(<String, String>{
      for (final f in visible)
        f.name:
            f.type == FormFieldKind.phone
                ? normalizeDigits((_values[f.name] ?? '').trim())
                : (_values[f.name] ?? '').trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = RaselnaChatColors.of(context);
    final s = widget.strings.shop;
    final p = widget.prompt;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SheetHeader(title: p.title ?? s.form, closeLabel: s.close),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            children: [
              if (p.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    p.error!,
                    style: c.style(size: 13.5, color: c.danger),
                  ),
                ),
              for (final f in p.fields.where(_visible))
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _field(context, f),
                ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: c.border)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: ShopButton(
            label: p.submitLabel ?? s.sendOrder,
            icon: Icons.check,
            onTap: _submit,
          ),
        ),
      ],
    );
  }

  Widget _field(BuildContext context, FormFieldSpec f) {
    final c = RaselnaChatColors.of(context);
    final s = widget.strings.shop;
    final error =
        _errors[f.name] ?? (_edited.contains(f.name) ? null : f.error);
    final label = Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: f.label,
            style: c.style(size: 14.5, weight: FontWeight.w700),
          ),
          if (!f.required)
            TextSpan(
              text: ' (${s.optional})',
              style: c.style(size: 12.5, color: c.mutedText),
            ),
        ],
      ),
    );
    void set(String v) => setState(() {
      _values[f.name] = v;
      _edited.add(f.name);
      _errors.remove(f.name);
    });

    if (f.type == FormFieldKind.choice) {
      return Semantics(
        container: true,
        label: f.label,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            label,
            const SizedBox(height: 6),
            for (final o in f.options)
              _ChoiceRow(
                label: o.label,
                hint: o.hint,
                selected: _values[f.name] == o.id,
                onTap: () => set(o.id),
              ),
            if (error != null) _Error(error),
          ],
        ),
      );
    }

    final phone = f.type == FormFieldKind.phone;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        label,
        const SizedBox(height: 6),
        TextFormField(
          initialValue: _values[f.name],
          onChanged: set,
          keyboardType:
              phone
                  ? TextInputType.phone
                  : f.type == FormFieldKind.textarea
                  ? TextInputType.multiline
                  : TextInputType.text,
          minLines: f.type == FormFieldKind.textarea ? 2 : 1,
          maxLines: f.type == FormFieldKind.textarea ? 4 : 1,
          maxLength: f.type == FormFieldKind.textarea ? 500 : (phone ? 20 : 80),
          textDirection: phone ? TextDirection.ltr : null,
          textAlign: phone ? TextAlign.end : TextAlign.start,
          autofillHints:
              phone
                  ? const [AutofillHints.telephoneNumber]
                  : f.name == 'name'
                  ? const [AutofillHints.name]
                  : f.name == 'address'
                  ? const [AutofillHints.fullStreetAddress]
                  : null,
          style: c.style(size: 16, height: 1.4),
          cursorColor: c.accent,
          decoration: InputDecoration(
            counterText: '',
            hintText: f.placeholder,
            hintStyle: c.style(size: 15, color: c.mutedText),
            filled: true,
            fillColor: c.background,
            errorText: error,
            errorStyle: c.style(size: 12.5, color: c.danger),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: c.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: c.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: c.accent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _Error extends StatelessWidget {
  const _Error(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = RaselnaChatColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Semantics(
        liveRegion: true,
        child: Text(text, style: c.style(size: 12.5, color: c.danger)),
      ),
    );
  }
}

/// The finder's price range: from / to, both optional, numbers only.
class RangeCard extends StatefulWidget {
  const RangeCard({
    super.key,
    required this.prompt,
    required this.strings,
    required this.onSubmit,
  });

  final FormPrompt prompt;
  final RaselnaStrings strings;

  /// (min, max) as typed digits ('' = any). Null = disabled.
  final void Function(String min, String max)? onSubmit;

  @override
  State<RangeCard> createState() => _RangeCardState();
}

class _RangeCardState extends State<RangeCard> {
  final _min = TextEditingController();
  final _max = TextEditingController();
  String? _error;

  static String _clean(String v) =>
      normalizeDigits(v).replaceAll(RegExp(r'[,\s٬]'), '');

  void _send({bool any = false}) {
    final min = any ? '' : _clean(_min.text);
    final max = any ? '' : _clean(_max.text);
    final ok = RegExp(r'^\d+(\.\d+)?$');
    if ([min, max].any((v) => v.isNotEmpty && !ok.hasMatch(v))) {
      setState(() => _error = widget.strings.shop.numbersOnly);
      return;
    }
    setState(() => _error = null);
    widget.onSubmit?.call(min, max);
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = RaselnaChatColors.of(context);
    final s = widget.strings.shop;
    final f = widget.prompt.fields;
    Widget box(TextEditingController t, String label, String? hint) => Expanded(
      child: TextField(
        controller: t,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        style: c.style(size: 16, height: 1.3),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: c.style(size: 14, color: c.mutedText),
          filled: true,
          fillColor: c.background,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: c.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: c.border),
          ),
        ),
      ),
    );
    return ChatCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.prompt.title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                widget.prompt.title!,
                style: c.style(size: 15, weight: FontWeight.w700),
              ),
            ),
          Row(
            children: [
              box(
                _min,
                f.isNotEmpty ? f[0].label : s.from,
                f.isNotEmpty ? f[0].placeholder : null,
              ),
              const SizedBox(width: 10),
              box(
                _max,
                f.length > 1 ? f[1].label : s.to,
                f.length > 1 ? f[1].placeholder : null,
              ),
            ],
          ),
          if (_error != null || widget.prompt.error != null)
            _Error(_error ?? widget.prompt.error!),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ShopButton(
                  label: widget.prompt.submitLabel ?? s.ok,
                  onTap: widget.onSubmit == null ? null : () => _send(),
                ),
              ),
              const SizedBox(width: 8),
              ShopButton(
                label: s.anyRange,
                primary: false,
                onTap: widget.onSubmit == null ? null : () => _send(any: true),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
