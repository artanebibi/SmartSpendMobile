import 'package:flutter/material.dart';

class AppThemeColors extends ThemeExtension<AppThemeColors> {
  const AppThemeColors({
    required this.bg,
    required this.card,
    required this.text,
    required this.border,
    required this.secondaryBg,
  });

  final Color bg;
  final Color card;
  final Color text;
  final Color border;
  final Color secondaryBg;

  static const light = AppThemeColors(
    bg:          Color(0xFFF5F7FA),
    card:        Color(0xFFFFFFFF),
    text:        Color(0xFF1A1A2E),
    border:      Color(0xFFE5E7EB),
    secondaryBg: Color(0xFFEEF3FF),
  );

  static const dark = AppThemeColors(
    bg:          Color(0xFF111827),
    card:        Color(0xFF1F2937),
    text:        Color(0xFFF9FAFB),
    border:      Color(0xFF374151),
    secondaryBg: Color(0xFF1E3A5F),
  );

  @override
  AppThemeColors copyWith({
    Color? bg,
    Color? card,
    Color? text,
    Color? border,
    Color? secondaryBg,
  }) =>
      AppThemeColors(
        bg:          bg ?? this.bg,
        card:        card ?? this.card,
        text:        text ?? this.text,
        border:      border ?? this.border,
        secondaryBg: secondaryBg ?? this.secondaryBg,
      );

  @override
  AppThemeColors lerp(AppThemeColors? other, double t) {
    if (other == null) return this;
    return AppThemeColors(
      bg:          Color.lerp(bg, other.bg, t)!,
      card:        Color.lerp(card, other.card, t)!,
      text:        Color.lerp(text, other.text, t)!,
      border:      Color.lerp(border, other.border, t)!,
      secondaryBg: Color.lerp(secondaryBg, other.secondaryBg, t)!,
    );
  }
}

extension AppThemeColorsX on BuildContext {
  AppThemeColors get colors =>
      Theme.of(this).extension<AppThemeColors>()!;
}
