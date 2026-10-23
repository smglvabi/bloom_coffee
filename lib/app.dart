import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'design.dart';
import 'domain.dart';
import 'duration_picker.dart';
import 'store.dart';
import 'export/exporter.dart';
import 'platform_keyboard.dart';

part 'screens/coffee.dart';
part 'screens/recipe.dart';
part 'screens/brewing.dart';
part 'screens/journal.dart';
part 'screens/equipment.dart';

class BloomApp extends StatelessWidget {
  final BloomStore store;
  const BloomApp({super.key, required this.store});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) => MaterialApp(
      title: 'Bloom — ваша следующая чашка',
      debugShowCheckedModeBanner: false,
      theme: bloomTheme(),
      darkTheme: bloomTheme(brightness: Brightness.dark),
      themeMode: store.themeMode,
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: context.colors.isDark
              ? Brightness.light
              : Brightness.dark,
          statusBarBrightness: context.colors.isDark
              ? Brightness.dark
              : Brightness.light,
          systemNavigationBarColor: context.colors.bg,
          systemNavigationBarDividerColor: context.colors.bg,
          systemNavigationBarIconBrightness: context.colors.isDark
              ? Brightness.light
              : Brightness.dark,
          systemNavigationBarContrastEnforced: false,
        ),
        child: ColoredBox(
          color: context.colors.track,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: IosKeyboardAccessory(child: child!),
            ),
          ),
        ),
      ),
      home: Home(store: store),
    ),
  );
}

void push(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

class Home extends StatefulWidget {
  final BloomStore store;
  const Home({super.key, required this.store});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int tab = 0;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) => Scaffold(
      body: SafeArea(
        bottom: widget.store.session?['state'] == 'timer',
        child: Column(
          children: [
            if (widget.store.session != null)
              Material(
                color: context.colors.track,
                child: InkWell(
                  onTap: () => resumeSession(context, widget.store),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
                    child: Row(
                      children: [
                        const Icon(Icons.timer_outlined, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.store.session!['state'] == 'timer'
                                ? 'Заваривание продолжается'
                                : 'Сохраните вашу чашку',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Icon(Icons.arrow_forward, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            Expanded(
              child: IndexedStack(
                index: tab,
                children: [
                  CoffeeList(store: widget.store),
                  Journal(store: widget.store),
                  EquipmentPage(store: widget.store),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: widget.store.session?['state'] == 'timer'
          ? null
          : Container(
              decoration: BoxDecoration(
                color: context.colors.bg,
                border: Border(top: BorderSide(color: context.colors.line)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  child: Row(
                    children: [
                      for (final (i, label, icon) in [
                        (0, 'Мой кофе', Icons.coffee_outlined),
                        (1, 'Журнал', Icons.menu_book_outlined),
                        (2, 'Оборудование', Icons.tune),
                      ])
                        Expanded(
                          child: Semantics(
                            button: true,
                            selected: tab == i,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => setState(() => tab = i),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      icon,
                                      color: tab == i
                                          ? context.colors.accent
                                          : context.colors.muted,
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: tab == i
                                            ? context.colors.accent
                                            : context.colors.muted,
                                        fontWeight: tab == i
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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

class FormFields {
  final Map<String, TextEditingController> controllers = {};
  TextEditingController c(String key, [String value = '']) =>
      controllers.putIfAbsent(key, () => TextEditingController(text: value));
  String text(String key) => c(key).text.trim();
  double n(String key) => double.parse(text(key).replaceAll(',', '.'));
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
  }

  Widget field(
    String key,
    String label, {
    String? initial,
    bool required = false,
    bool numeric = false,
    double min = .1,
    double max = 10000,
    String? suffix,
    int lines = 1,
    ValueChanged<String>? onChanged,
    bool integer = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: c(key, initial ?? ''),
        maxLines: lines,
        onChanged: onChanged,
        textInputAction: lines == 1 ? TextInputAction.done : TextInputAction.newline,
        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        keyboardType: numeric
            ? TextInputType.numberWithOptions(decimal: !integer)
            : (lines > 1 ? TextInputType.multiline : TextInputType.text),
        style: numeric ? mono(16) : const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffix,
          alignLabelWithHint: lines > 1,
        ),
        validator: (v) {
          final value = (v ?? '').trim();
          if (required && value.isEmpty) return 'Заполните это поле';
          if (numeric && value.isNotEmpty) {
            final n = double.tryParse(value.replaceAll(',', '.'));
            if (n == null ||
                !n.isFinite ||
                n < min ||
                n > max ||
                (integer && n != n.roundToDouble())) {
              return 'Введите ${integer ? 'целое число' : 'число'} от ${amount(min)} до ${amount(max)}';
            }
          }
          return null;
        },
      ),
    );
  }
}

Future<bool> checkStock(
  BuildContext context,
  BloomStore store,
  Json recipe,
) async {
  final p = store.pack(recipe['packId']);
  if (number(p['remaining']) >= number(recipe['dose'])) return true;
  final check = await confirm(
    context,
    title: 'Проверьте остаток',
    message:
        'Расчётный остаток — ${amount(p['remaining'])} г, для чашки нужно ${amount(recipe['dose'])} г. Взвесьте зерно и уточните массу.',
    action: 'Уточнить массу',
  );
  if (!check || !context.mounted) return false;
  final value = await editText(
    context,
    title: 'Фактический остаток, г',
    initial: amount(p['remaining']),
    numeric: true,
  );
  if (value == null) return false;
  await store.savePack(
    clone(p)..['remaining'] = double.parse(value.replaceAll(',', '.')),
  );
  return number(store.pack(p['id'])['remaining']) >= number(recipe['dose']);
}

void openRecipe(
  BuildContext context,
  BloomStore store,
  String packId, {
  Json? recipe,
  bool fromBrew = false,
}) {
  final plan = recipe == null ? newRecipe(packId, store.kit) : clone(recipe);
  if (fromBrew) {
    final lastTime = (plan['steps'] as List).last['time'] as int;
    if (plan['duration'] <= lastTime) plan['duration'] = lastTime + 30;
  }
  push(
    context,
    RecipePage(store: store, recipe: plan, isNew: recipe == null || fromBrew),
  );
}

void resumeSession(BuildContext context, BloomStore store) {
  if (store.session == null) return;
  push(
    context,
    store.session!['state'] == 'timer'
        ? TimerPage(store: store)
        : ResultPage(store: store),
  );
}
