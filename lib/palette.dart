import 'package:flutter/material.dart';

@immutable
class BloomColors extends ThemeExtension<BloomColors> {
  final Color bg, ink, surface, muted, line, track, terra;
  final Color accent, onAccent, selected, onSelected, onTerra;
  final bool isDark;

  const BloomColors({
    required this.bg,
    required this.ink,
    required this.surface,
    required this.muted,
    required this.line,
    required this.track,
    required this.terra,
    required this.accent,
    required this.onAccent,
    required this.selected,
    required this.onSelected,
    required this.onTerra,
    required this.isDark,
  });

  static const light = BloomColors(
    bg: Color(0xFFF5EFE6),
    ink: Color(0xFF302820),
    surface: Color(0xFFFFFCF8),
    muted: Color(0xFF6F6962),
    line: Color(0xFFE2DAD0),
    track: Color(0xFFE7DFD4),
    terra: Color(0xFFB65A3A),
    accent: Color(0xFF302820),
    onAccent: Color(0xFFFFFCF8),
    selected: Color(0xFFE7DFD4),
    onSelected: Color(0xFF302820),
    onTerra: Color(0xFFFFFCF8),
    isDark: false,
  );

  static const dark = BloomColors(
    bg: Color(0xFF1E1A17),
    ink: Color(0xFFF5EFE6),
    surface: Color(0xFF29231F),
    muted: Color(0xFFB7ADA2),
    line: Color(0xFF463C33),
    track: Color(0xFF38302A),
    terra: Color(0xFFD68D6D),
    accent: Color(0xFFE9DCCB),
    onAccent: Color(0xFF241E19),
    selected: Color(0xFFE9DCCB),
    onSelected: Color(0xFF241E19),
    onTerra: Color(0xFF241E19),
    isDark: true,
  );

  @override
  BloomColors copyWith({
    Color? bg,
    Color? ink,
    Color? surface,
    Color? muted,
    Color? line,
    Color? track,
    Color? terra,
    Color? accent,
    Color? onAccent,
    Color? selected,
    Color? onSelected,
    Color? onTerra,
    bool? isDark,
  }) => BloomColors(
    bg: bg ?? this.bg,
    ink: ink ?? this.ink,
    surface: surface ?? this.surface,
    muted: muted ?? this.muted,
    line: line ?? this.line,
    track: track ?? this.track,
    terra: terra ?? this.terra,
    accent: accent ?? this.accent,
    onAccent: onAccent ?? this.onAccent,
    selected: selected ?? this.selected,
    onSelected: onSelected ?? this.onSelected,
    onTerra: onTerra ?? this.onTerra,
    isDark: isDark ?? this.isDark,
  );

  @override
  BloomColors lerp(covariant BloomColors? other, double t) {
    if (other == null) return this;
    return BloomColors(
      bg: Color.lerp(bg, other.bg, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      line: Color.lerp(line, other.line, t)!,
      track: Color.lerp(track, other.track, t)!,
      terra: Color.lerp(terra, other.terra, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      selected: Color.lerp(selected, other.selected, t)!,
      onSelected: Color.lerp(onSelected, other.onSelected, t)!,
      onTerra: Color.lerp(onTerra, other.onTerra, t)!,
      isDark: t < .5 ? isDark : other.isDark,
    );
  }
}

extension BloomPaletteContext on BuildContext {
  BloomColors get colors {
    final theme = Theme.of(this);
    return theme.extension<BloomColors>() ??
        (theme.brightness == Brightness.dark
            ? BloomColors.dark
            : BloomColors.light);
  }
}
