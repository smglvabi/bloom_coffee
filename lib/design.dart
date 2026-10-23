import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'domain.dart';
import 'palette.dart';

export 'palette.dart';

abstract final class C {
  static const bg = Color(0xFFF5EFE6);
  static const ink = Color(0xFF302820);
  static const surface = Color(0xFFFFFCF8);
  static const muted = Color(0xFF6F6962);
  static const line = Color(0xFFE2DAD0);
  static const track = Color(0xFFE7DFD4);
  static const terra = Color(0xFFB65A3A);
}

TextStyle mono([double size = 14, Color? color]) => TextStyle(
  fontFamily: 'IBM Plex Mono',
  fontSize: size,
  fontWeight: FontWeight.w400,
  color: color,
  fontFeatures: const [FontFeature.tabularFigures()],
);

TextStyle timerDigits(double size, [Color? color]) => TextStyle(
  fontFamily: 'IBM Plex Mono',
  fontSize: size,
  fontWeight: FontWeight.w600,
  height: 1,
  letterSpacing: -2.5,
  color: color,
  fontFeatures: const [FontFeature.tabularFigures()],
);

ThemeData bloomTheme({Brightness brightness = Brightness.light}) {
  final colors = brightness == Brightness.dark
      ? BloomColors.dark
      : BloomColors.light;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: colors.accent,
    onPrimary: colors.onAccent,
    primaryContainer: colors.selected,
    onPrimaryContainer: colors.onSelected,
    secondary: colors.terra,
    onSecondary: colors.onTerra,
    secondaryContainer: colors.selected,
    onSecondaryContainer: colors.onSelected,
    tertiary: colors.terra,
    onTertiary: colors.onTerra,
    tertiaryContainer: colors.track,
    onTertiaryContainer: colors.ink,
    error: colors.terra,
    onError: colors.onTerra,
    errorContainer: colors.track,
    onErrorContainer: colors.terra,
    surface: colors.surface,
    onSurface: colors.ink,
    onSurfaceVariant: colors.muted,
    outline: colors.line,
    outlineVariant: colors.line,
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: colors.accent,
    onInverseSurface: colors.onAccent,
    inversePrimary: colors.onAccent,
    surfaceTint: Colors.transparent,
    surfaceContainerLowest: colors.bg,
    surfaceContainerLow: colors.surface,
    surfaceContainer: colors.surface,
    surfaceContainerHigh: colors.track,
    surfaceContainerHighest: colors.track,
  );
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter',
    brightness: brightness,
    colorScheme: scheme,
  );
  final textTheme = base.textTheme
      .apply(bodyColor: colors.ink, displayColor: colors.ink)
      .copyWith(
        headlineLarge: TextStyle(
          fontFamily: 'Inter',
          fontSize: 32,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.1,
          color: colors.ink,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: 26,
          fontWeight: FontWeight.w700,
          letterSpacing: -.7,
          color: colors.ink,
        ),
        titleLarge: TextStyle(
          fontFamily: 'Inter',
          fontSize: 21,
          fontWeight: FontWeight.w600,
          letterSpacing: -.4,
          color: colors.ink,
        ),
        titleMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: colors.ink,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.5,
          color: colors.ink,
        ),
        bodySmall: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w400,
          height: 1.45,
          color: colors.muted,
        ),
      );
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: colors.line),
  );
  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  );
  final selectedText = WidgetStateColor.resolveWith((states) {
    if (states.contains(WidgetState.disabled)) return colors.muted;
    return states.contains(WidgetState.selected)
        ? colors.onSelected
        : colors.ink;
  });
  final selectedBackground = WidgetStateProperty.resolveWith<Color?>((states) {
    if (states.contains(WidgetState.disabled)) return colors.track;
    return states.contains(WidgetState.selected)
        ? colors.selected
        : colors.surface;
  });
  return base.copyWith(
    cupertinoOverrideTheme: CupertinoThemeData(
      brightness: brightness,
      primaryColor: colors.accent,
      scaffoldBackgroundColor: colors.bg,
      barBackgroundColor: colors.bg,
    ),
    extensions: <ThemeExtension<dynamic>>[colors],
    scaffoldBackgroundColor: colors.bg,
    canvasColor: colors.bg,
    dividerColor: colors.line,
    disabledColor: colors.muted.withValues(alpha: .55),
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: colors.bg,
      foregroundColor: colors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: colors.bg,
        statusBarIconBrightness: colors.isDark
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: brightness,
        systemNavigationBarColor: colors.bg,
        systemNavigationBarDividerColor: colors.line,
        systemNavigationBarIconBrightness: colors.isDark
            ? Brightness.light
            : Brightness.dark,
      ),
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: colors.ink,
      ),
    ),
    dividerTheme: DividerThemeData(color: colors.line, thickness: 1, space: 32),
    iconTheme: IconThemeData(color: colors.ink, size: 22),
    primaryIconTheme: IconThemeData(color: colors.onAccent, size: 22),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: TextStyle(color: colors.muted, fontSize: 14),
      hintStyle: TextStyle(color: colors.muted),
      helperStyle: TextStyle(color: colors.muted),
      floatingLabelStyle: TextStyle(color: colors.ink),
      errorStyle: TextStyle(color: colors.terra),
      prefixIconColor: colors.muted,
      suffixIconColor: colors.muted,
      border: border,
      enabledBorder: border,
      disabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: colors.accent, width: 1.4),
      ),
      errorBorder: border.copyWith(borderSide: BorderSide(color: colors.terra)),
      focusedErrorBorder: border.copyWith(
        borderSide: BorderSide(color: colors.terra, width: 1.4),
      ),
      errorMaxLines: 3,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: colors.accent,
      selectionColor: colors.accent.withValues(alpha: .25),
      selectionHandleColor: colors.accent,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colors.accent,
        foregroundColor: colors.onAccent,
        disabledBackgroundColor: colors.track,
        disabledForegroundColor: colors.muted,
        minimumSize: const Size(44, 52),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        shape: buttonShape,
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.ink,
        disabledForegroundColor: colors.muted,
        minimumSize: const Size(44, 50),
        side: BorderSide(color: colors.line),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        shape: buttonShape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colors.accent,
        disabledForegroundColor: colors.muted,
        minimumSize: const Size(44, 44),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: colors.surface,
      selectedColor: colors.selected,
      disabledColor: colors.track,
      checkmarkColor: colors.onSelected,
      side: BorderSide(color: colors.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      labelStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        color: selectedText,
      ),
      secondaryLabelStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        color: selectedText,
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return colors.muted;
        return states.contains(WidgetState.selected)
            ? colors.onAccent
            : colors.muted;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return colors.track;
        return states.contains(WidgetState.selected)
            ? colors.accent
            : colors.track;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.transparent
            : colors.line,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? colors.accent
            : colors.surface,
      ),
      checkColor: WidgetStatePropertyAll(colors.onAccent),
      side: BorderSide(color: colors.muted),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? colors.accent
            : colors.muted,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: selectedBackground,
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.onSelected
              : colors.ink,
        ),
        side: WidgetStatePropertyAll(BorderSide(color: colors.line)),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
        ),
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: colors.accent,
      inactiveTrackColor: colors.track,
      thumbColor: colors.accent,
      overlayColor: colors.accent.withValues(alpha: .12),
      valueIndicatorColor: colors.accent,
      valueIndicatorTextStyle: TextStyle(color: colors.onAccent),
    ),
    cardTheme: CardThemeData(
      color: colors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.bg,
      modalBackgroundColor: colors.bg,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: colors.muted,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.bg,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyMedium,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: colors.surface,
      surfaceTintColor: Colors.transparent,
      textStyle: textTheme.bodyMedium,
      labelTextStyle: WidgetStatePropertyAll(textTheme.bodyMedium),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(colors.surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        side: WidgetStatePropertyAll(BorderSide(color: colors.line)),
      ),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(textStyle: textTheme.bodyMedium),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: colors.bg,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: colors.bg,
      headerForegroundColor: colors.ink,
      dividerColor: colors.line,
      dayForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return colors.muted.withValues(alpha: .55);
        }
        return states.contains(WidgetState.selected)
            ? colors.onAccent
            : colors.ink;
      }),
      dayBackgroundColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? colors.accent : null,
      ),
      todayForegroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? colors.onAccent
            : colors.accent,
      ),
      todayBorder: BorderSide(color: colors.accent),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: colors.accent,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: TextStyle(fontFamily: 'Inter', color: colors.onAccent),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colors.accent,
      contentTextStyle: TextStyle(fontFamily: 'Inter', color: colors.onAccent),
      actionTextColor: colors.onAccent,
      behavior: SnackBarBehavior.floating,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colors.accent,
      linearTrackColor: colors.track,
      circularTrackColor: colors.track,
    ),
  );
}

class Surface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const Surface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: context.colors.line),
    ),
    child: child,
  );
}

class SectionLabel extends StatelessWidget {
  final String text;
  final Widget? action;
  final TextStyle? style;
  const SectionLabel(this.text, {super.key, this.action, this.style});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 28, bottom: 14),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: style ?? Theme.of(context).textTheme.titleMedium,
          ),
        ),
        ?action,
      ],
    ),
  );
}

class Primary extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  const Primary(this.text, {super.key, this.onPressed, this.icon});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: icon == null
        ? FilledButton(
            onPressed: onPressed,
            child: Text(text, textAlign: TextAlign.center),
          )
        : FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 18),
            label: Text(text, textAlign: TextAlign.center),
          ),
  );
}

class EmptyState extends StatelessWidget {
  final String title, subtitle, action;
  final VoidCallback onPressed;
  final IconData icon;
  const EmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    required this.action,
    required this.onPressed,
    this.icon = Icons.coffee_outlined,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 8),
    child: Column(
      children: [
        Icon(icon, size: 42, color: context.colors.muted),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.colors.muted, height: 1.6),
        ),
        const SizedBox(height: 22),
        OutlinedButton(onPressed: onPressed, child: Text(action)),
      ],
    ),
  );
}

class Metric extends StatelessWidget {
  final String value, label;
  const Metric(this.value, this.label, {super.key});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(value, style: mono(18)),
      const SizedBox(height: 4),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class InfoRow extends StatelessWidget {
  final String label, value;
  final TextStyle? labelStyle, valueStyle;
  final int labelFlex, valueFlex;
  const InfoRow(
    this.label,
    this.value, {
    super.key,
    this.labelStyle,
    this.valueStyle,
    this.labelFlex = 1,
    this.valueFlex = 1,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: labelFlex,
          child: Text(
            label,
            style:
                labelStyle ??
                TextStyle(color: context.colors.muted, fontSize: 13),
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          flex: valueFlex,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: valueStyle ?? const TextStyle(fontSize: 13),
          ),
        ),
      ],
    ),
  );
}

class CoffeeCover extends StatelessWidget {
  final Json pack;
  final double height;
  const CoffeeCover(this.pack, {super.key, this.height = 168});
  @override
  Widget build(BuildContext context) {
    if (pack['photo'] != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          base64Decode(pack['photo']),
          height: height,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _art(context),
        ),
      );
    }
    return _art(context);
  }

  Widget _art(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _CoverPainter(pack['cover'] == 1, context.colors),
      ),
    ),
  );
}

class _CoverPainter extends CustomPainter {
  final bool light;
  final BloomColors colors;
  _CoverPainter(this.light, this.colors);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    canvas.drawRect(
      Offset.zero & size,
      p
        ..color = colors.isDark
            ? (light
                  ? colors.track
                  : Color.lerp(colors.surface, colors.track, .65)!)
            : (light ? const Color(0xFFE8D9C7) : const Color(0xFFE9E1D5)),
    );
    // Quiet contour lines evoke the growing region, without stock decoration.
    p
      ..color = colors.ink.withValues(alpha: .08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < 7; i++) {
      final path = Path()..moveTo(-20, size.height * .6 + i * 10);
      path.cubicTo(
        size.width * .25,
        -30 + i * 11,
        size.width * .7,
        size.height * 1.4 + i * 5,
        size.width + 20,
        15 + i * 15,
      );
      canvas.drawPath(path, p);
    }
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2 + 2);
    canvas.rotate(light ? .1 : -.08);
    final h = math.min(size.height * .84, 175.0), w = h * .69;
    final bag = Path()
      ..moveTo(-w / 2 + 8, -h / 2)
      ..lineTo(w / 2 - 8, -h / 2)
      ..lineTo(w / 2, h / 2 - 7)
      ..lineTo(w / 2 - 7, h / 2)
      ..lineTo(-w / 2 + 7, h / 2)
      ..lineTo(-w / 2, h / 2 - 7)
      ..close();
    p
      ..style = PaintingStyle.fill
      ..color = light ? const Color(0xFFB65A3A) : C.ink;
    canvas.drawPath(bag, p);
    canvas.drawLine(
      Offset(-w / 2 + 10, -h / 2 + 8),
      Offset(w / 2 - 10, -h / 2 + 8),
      Paint()
        ..color = C.surface.withValues(alpha: .25)
        ..strokeWidth = 1,
    );
    final label = Rect.fromLTWH(-w * .37, -h * .23, w * .74, h * .53);
    canvas.drawRect(label, p..color = C.bg);
    void text(String value, double y, double fs, {Color color = C.ink}) {
      final tp = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: fs,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: w * .7);
      tp.paint(canvas, Offset(-tp.width / 2, y));
    }

    text(light ? 'северный' : 'тихий', -h * .18, h * .071);
    text(light ? 'склон' : 'обжарщик', -h * .09, h * .071);
    canvas.drawCircle(Offset(0, h * .085), h * .055, p..color = C.terra);
    text(light ? 'COLOMBIA' : 'ETHIOPIA', h * .19, h * .045);
    text('FILTER COFFEE', h * .36, h * .04, color: C.surface);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CoverPainter oldDelegate) =>
      light != oldDelegate.light || colors != oldDelegate.colors;
}

void toast(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
Future<void> guard(BuildContext context, Future<void> Function() action) async {
  try {
    await action();
  } catch (e) {
    if (context.mounted) {
      toast(context, 'Не удалось сохранить. Попробуйте ещё раз.');
    }
    debugPrint('$e');
  }
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String action = 'Подтвердить',
  String cancel = 'Назад',
}) async =>
    await showAdaptiveDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: Text(title),
        content: Text(message),
        actions: [
          if (Theme.of(context).platform == TargetPlatform.iOS ||
              Theme.of(context).platform == TargetPlatform.macOS) ...[
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context, false),
              child: Text(cancel),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ] else ...[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ],
      ),
    ) ??
    false;

Future<String?> editText(
  BuildContext context, {
  required String title,
  String initial = '',
  bool numeric = false,
}) async {
  final controller = TextEditingController(text: initial);
  final key = GlobalKey<FormState>();
  final value = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Form(
        key: key,
        child: TextFormField(
          controller: controller,
          autofocus: true,
          maxLines: numeric ? 1 : 3,
          textInputAction: numeric
              ? TextInputAction.done
              : TextInputAction.newline,
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          keyboardType: numeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.multiline,
          validator: (v) {
            if (!numeric) return null;
            final n = double.tryParse((v ?? '').replaceAll(',', '.'));
            return n == null || !n.isFinite || n < 0 || n > 10000
                ? 'Введите массу от 0 до 10 000 г'
                : null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () {
            if (key.currentState!.validate()) {
              Navigator.pop(ctx, controller.text.trim());
            }
          },
          child: const Text('Сохранить'),
        ),
      ],
    ),
  );
  // The dialog may still animate out, so its field owns the controller until then.
  Future.delayed(const Duration(seconds: 1), controller.dispose);
  return value;
}
