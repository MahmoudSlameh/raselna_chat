import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'models.dart';

/// Optional overrides on top of the business's colours. Any field left null
/// comes from the palette the API returns (or Raselna's default).
@immutable
class RaselnaChatTheme {
  const RaselnaChatTheme({
    this.primary,
    this.onPrimary,
    this.accent,
    this.tint,
    this.background,
    this.surface,
    this.text,
    this.mutedText,
    this.border,
    this.fontFamily,
    this.fontPackage,
    this.radius,
    this.showPattern,
  });

  final Color? primary;
  final Color? onPrimary;

  /// Chips, links and small coloured text.
  final Color? accent;

  /// Soft background of chips and selected rows.
  final Color? tint;
  final Color? background;
  final Color? surface;
  final Color? text;
  final Color? mutedText;
  final Color? border;

  /// Defaults to the bundled Tajawal. Set your app's font family to use it
  /// instead (and [fontPackage] to null).
  final String? fontFamily;
  final String? fontPackage;
  final double? radius;

  /// The faint geometric pattern behind the messages.
  final bool? showPattern;
}

/// The resolved colours the widgets read (see [RaselnaChatColors.of]).
@immutable
class RaselnaChatColors {
  const RaselnaChatColors({
    required this.brightness,
    required this.primary,
    required this.onPrimary,
    required this.accent,
    required this.tint,
    required this.onTint,
    required this.page,
    required this.background,
    required this.surface,
    required this.text,
    required this.mutedText,
    required this.border,
    required this.danger,
    required this.success,
    required this.warning,
    required this.spark,
    required this.fontFamily,
    required this.fontPackage,
    required this.radius,
    required this.showPattern,
  });

  /// Raselna's fallback tenant colour (ink indigo), for when no palette came.
  static const fallbackPrimary = Color(0xFF4A5192);

  /// Builds the colours from the business's [palette] for [brightness],
  /// then applies [overrides].
  factory RaselnaChatColors.resolve({
    TenantPalette? palette,
    required Brightness brightness,
    RaselnaChatTheme? overrides,
  }) {
    final o = overrides ?? const RaselnaChatTheme();
    final p = palette ?? const TenantPalette(primary: fallbackPrimary);
    final primary = o.primary ?? p.primary;
    final derived = derivePalette(primary);
    final onPrimary = o.onPrimary ?? p.primaryFg ?? derived.onPrimary;
    final dark = brightness == Brightness.dark;

    final background =
        o.background ??
        (dark ? const Color(0xFF0F1016) : const Color(0xFFF2F3F8));
    final accent =
        o.accent ??
        (dark
            ? (p.primaryDark ?? derived.dark)
            : (p.primaryStrong ?? derived.strong));
    final tint =
        o.tint ??
        (dark
            ? Color.lerp(background, accent, 0.14)!
            : (p.primaryTint ?? derived.tint));

    return RaselnaChatColors(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      accent: accent,
      tint: tint,
      onTint: accent,
      page: dark ? const Color(0xFF08090D) : const Color(0xFFE5E6EC),
      background: background,
      surface:
          o.surface ??
          (dark ? const Color(0xFF1A1B23) : const Color(0xFFFFFFFF)),
      text:
          o.text ?? (dark ? const Color(0xFFECEEF4) : const Color(0xFF0C0D18)),
      mutedText:
          o.mutedText ??
          (dark ? const Color(0xFFA3A6B3) : const Color(0xFF555762)),
      border:
          o.border ??
          (dark ? const Color(0xFF2A2C37) : const Color(0xFFE5E6EC)),
      danger: dark ? const Color(0xFFFFABA3) : const Color(0xFFC51D28),
      success: dark ? const Color(0xFFB8D07E) : const Color(0xFF56791B),
      warning: dark ? const Color(0xFFFEB16A) : const Color(0xFFA75001),
      spark: const Color(0xFFFAB048),
      fontFamily: o.fontFamily ?? 'Tajawal',
      fontPackage: o.fontFamily == null ? 'raselna_chat' : o.fontPackage,
      radius: o.radius ?? 18,
      showPattern: o.showPattern ?? true,
    );
  }

  final Brightness brightness;
  final Color primary;
  final Color onPrimary;
  final Color accent;
  final Color tint;
  final Color onTint;
  final Color page;
  final Color background;
  final Color surface;
  final Color text;
  final Color mutedText;
  final Color border;
  final Color danger;
  final Color success;
  final Color warning;

  /// Raselna saffron, used sparingly (never as text).
  final Color spark;
  final String fontFamily;
  final String? fontPackage;
  final double radius;
  final bool showPattern;

  bool get isDark => brightness == Brightness.dark;

  TextStyle style({
    double size = 15,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double height = 1.55,
  }) => TextStyle(
    fontFamily: fontFamily,
    package: fontPackage,
    fontSize: size,
    fontWeight: weight,
    color: color ?? text,
    height: height,
  );

  static RaselnaChatColors of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<RaselnaChatColorsScope>();
    assert(
      scope != null,
      'RaselnaChatColors.of() called outside RaselnaChatView',
    );
    return scope!.colors;
  }
}

class RaselnaChatColorsScope extends InheritedWidget {
  const RaselnaChatColorsScope({
    super.key,
    required this.colors,
    required super.child,
  });

  final RaselnaChatColors colors;

  @override
  bool updateShouldNotify(RaselnaChatColorsScope oldWidget) =>
      colors != oldWidget.colors;
}

/// The tones the server would send, computed on the device when the API
/// gave only a primary colour. Same rules as the web chat: text on primary
/// reaches 4.5:1, `strong` reaches 4.5:1 on white, `dark` on the dark
/// surface.
({Color onPrimary, Color strong, Color tint, Color dark}) derivePalette(
  Color primary,
) {
  const white = Color(0xFFFFFFFF);
  const darkSurface = Color(0xFF1A1B23);

  final onPrimary =
      contrastRatio(white, primary) >= 4.5
          ? white
          : _shift(
            primary,
            toward: const Color(0xFF000000),
            until: (c) => contrastRatio(c, primary) >= 4.5,
          );
  final strong =
      contrastRatio(primary, white) >= 4.5
          ? primary
          : _shift(
            primary,
            toward: const Color(0xFF000000),
            until: (c) => contrastRatio(c, white) >= 4.5,
          );
  final tint = Color.lerp(white, primary, 0.08)!;
  final dark = _shift(
    primary,
    toward: white,
    until: (c) => contrastRatio(c, darkSurface) >= 4.5,
  );
  return (onPrimary: onPrimary, strong: strong, tint: tint, dark: dark);
}

Color _shift(
  Color from, {
  required Color toward,
  required bool Function(Color) until,
}) {
  for (var t = 0.0; t <= 1.0; t += 0.04) {
    final c = Color.lerp(from, toward, t)!;
    if (until(c)) return c;
  }
  return toward;
}

/// WCAG contrast ratio between two opaque colours.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}
