import 'dart:async';

import 'package:bloom/app.dart';
import 'package:bloom/database.dart';
import 'package:bloom/design.dart';
import 'package:bloom/domain.dart';
import 'package:bloom/store.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late BloomStore store;

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    store = BloomStore(
      await openBloomDatabase(
        factoryOverride: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      ),
    );
    await store.load();
  });
  tearDown(() async {
    store.dispose();
    await store.db.close();
  });

  void phone(WidgetTester tester, double width) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 852);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  void systemBrightness(WidgetTester tester, Brightness brightness) {
    tester.platformDispatcher.platformBrightnessTestValue = brightness;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  }

  Widget darkFrame(Widget page) => MaterialApp(
    theme: bloomTheme(),
    darkTheme: bloomTheme(
      brightness: Brightness.dark,
    ).copyWith(platform: TargetPlatform.android),
    themeMode: ThemeMode.dark,
    locale: const Locale('ru'),
    supportedLocales: const [Locale('ru')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: page,
  );

  Finder field(String label) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );

  String fieldValue(WidgetTester tester, String label) =>
      tester.widget<TextField>(field(label)).controller!.text;

  ThemeData renderedTheme(WidgetTester tester, Finder page) =>
      Theme.of(tester.element(page));

  Future<void> setMode(WidgetTester tester, ThemeMode mode) async {
    await tester.runAsync(() => store.setThemeMode(mode));
    await tester.pumpAndSettle();
  }

  test(
    'Theme defaults to system and all choices survive a new store',
    () async {
      final packs = store.packs.map(clone).toList();
      final brews = store.brews.map(clone).toList();
      final recipes = store.recipes.map(clone).toList();
      expect(store.themeMode, ThemeMode.system);

      for (final mode in [ThemeMode.dark, ThemeMode.light, ThemeMode.system]) {
        await store.setThemeMode(mode);
        final reopened = BloomStore(store.db);
        try {
          await reopened.load();
          expect(reopened.themeMode, mode);
          expect(reopened.packs, packs);
          expect(reopened.brews, brews);
          expect(reopened.recipes, recipes);
        } finally {
          reopened.dispose();
        }
      }
    },
  );

  test(
    'Missing or unknown appearance falls back without replacing data',
    () async {
      final packs = store.packs.map(clone).toList();
      final brews = store.brews.map(clone).toList();
      await store.setThemeMode(ThemeMode.dark);
      await store.setting('appearance', {'theme': 'unknown-future-theme'});
      await store.load();
      expect(store.themeMode, ThemeMode.system);
      expect(store.packs, packs);
      expect(store.brews, brews);

      await store.setThemeMode(ThemeMode.light);
      await store.db.delete(
        'settings',
        where: 'id = ?',
        whereArgs: ['appearance'],
      );
      await store.load();
      expect(store.themeMode, ThemeMode.system);
      expect(store.packs, packs);
      expect(store.brews, brews);
    },
  );

  testWidgets(
    'Equipment selector applies and saves a theme without changing tabs',
    (tester) async {
      phone(tester, 393);
      systemBrightness(tester, Brightness.light);
      await tester.pumpWidget(BloomApp(store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Оборудование').last);
      await tester.pumpAndSettle();
      final homeState = tester.state(find.byType(Home));
      final selector = find.byKey(const ValueKey('theme-selector'));
      final equipmentScroll = find.descendant(
        of: find.byType(EquipmentPage),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        selector,
        250,
        scrollable: equipmentScroll.first,
      );
      await tester.pumpAndSettle();

      for (final (mode, label, brightness) in [
        (ThemeMode.dark, 'Тёмная', Brightness.dark),
        (ThemeMode.light, 'Светлая', Brightness.light),
        (ThemeMode.system, 'Системная', Brightness.light),
      ]) {
        await tester.tap(selector);
        await tester.pumpAndSettle();
        final changed = Completer<void>();
        void onChanged() {
          if (store.themeMode == mode && !changed.isCompleted) {
            changed.complete();
          }
        }

        store.addListener(onChanged);
        try {
          await tester.tap(find.text(label).last);
          // Drive Flutter's fake scheduler and SQLite's real event queue
          // together until the persisted change reaches the UI listener.
          final waiting = Stopwatch()..start();
          while (!changed.isCompleted &&
              waiting.elapsed < const Duration(seconds: 10)) {
            await tester.pump();
            await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          }
          expect(
            changed.isCompleted,
            isTrue,
            reason: 'Theme selection must finish its SQLite write within 10s',
          );
        } finally {
          store.removeListener(onChanged);
        }
        await tester.pumpAndSettle();

        expect(tester.state(find.byType(Home)), same(homeState));
        expect(
          tester.widget<IndexedStack>(find.byType(IndexedStack).first).index,
          2,
        );
        expect(tester.widget<DropdownButton<ThemeMode>>(selector).value, mode);
        expect(renderedTheme(tester, selector).brightness, brightness);

        final reopened = BloomStore(store.db);
        try {
          await tester.runAsync(reopened.load);
          expect(reopened.themeMode, mode);
          expect(reopened.packs.length, 2);
          expect(reopened.brews.length, 3);
        } finally {
          reopened.dispose();
        }
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'System appearance follows the device while explicit modes override it',
    (tester) async {
      phone(tester, 393);
      systemBrightness(tester, Brightness.light);
      await tester.pumpWidget(BloomApp(store: store));
      await tester.pumpAndSettle();
      final home = find.byType(Home);

      void expectBrightness(Brightness brightness) {
        final theme = renderedTheme(tester, home);
        expect(theme.brightness, brightness);
        expect(
          theme.scaffoldBackgroundColor,
          brightness == Brightness.dark
              ? BloomColors.dark.bg
              : BloomColors.light.bg,
        );
      }

      expectBrightness(Brightness.light);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expectBrightness(Brightness.dark);

      await setMode(tester, ThemeMode.light);
      expectBrightness(Brightness.light);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpAndSettle();
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expectBrightness(Brightness.light);

      await setMode(tester, ThemeMode.dark);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpAndSettle();
      expectBrightness(Brightness.dark);

      await setMode(tester, ThemeMode.system);
      expectBrightness(Brightness.light);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expectBrightness(Brightness.dark);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'An open recipe keeps unsaved input and its route when the theme changes',
    (tester) async {
      phone(tester, 393);
      systemBrightness(tester, Brightness.light);
      await tester.pumpWidget(BloomApp(store: store));
      await tester.pumpAndSettle();
      openRecipe(
        tester.element(find.byType(Home)),
        store,
        'sidamo',
        recipe: store.recipes.first,
      );
      await tester.pumpAndSettle();
      final recipeState = tester.state(find.byType(RecipePage));
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      await tester.enterText(
        field('Название рецепта'),
        'Мой вечерний эксперимент',
      );
      await tester.enterText(field('Кофе'), '20');
      await tester.enterText(field('Вода'), '310');
      await tester.pump();
      final recipeBefore = clone(store.recipes.first);
      final brewsBefore = store.brews.map(clone).toList();

      for (final mode in [ThemeMode.dark, ThemeMode.light]) {
        await setMode(tester, mode);
        expect(tester.state(find.byType(RecipePage)), same(recipeState));
        expect(
          tester.state<NavigatorState>(find.byType(Navigator)),
          same(navigator),
        );
        expect(navigator.canPop(), isTrue);
        expect(
          fieldValue(tester, 'Название рецепта'),
          'Мой вечерний эксперимент',
        );
        expect(fieldValue(tester, 'Кофе'), '20');
        expect(fieldValue(tester, 'Вода'), '310');
        expect(fieldValue(tester, 'Пропорция'), '15,5');
        expect(
          renderedTheme(tester, find.byType(RecipePage)).brightness,
          mode == ThemeMode.dark ? Brightness.dark : Brightness.light,
        );
        expect(store.recipes.first, recipeBefore);
        expect(store.brews, brewsBefore);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Dark journal chip text stays readable before and after filtering',
    (tester) async {
      phone(tester, 393);
      await tester.pumpWidget(darkFrame(Scaffold(body: Journal(store: store))));
      await tester.pumpAndSettle();

      void expectReadableChips() {
        final chips = find.byType(FilterChip);
        expect(chips, findsNWidgets(4));
        for (var i = 0; i < 4; i++) {
          final chipFinder = chips.at(i);
          final chip = tester.widget<FilterChip>(chipFinder);
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: chipFinder, matching: find.byType(RichText)),
          );
          final style = paragraph.text.style;
          final foreground = style?.foreground?.color ?? style?.color;
          final label = (chip.label as Text).data;
          expect(
            foreground,
            isNotNull,
            reason: '$label has resolved text paint',
          );
          final ink = tester.widget<Ink>(
            find.descendant(of: chipFinder, matching: find.byType(Ink)),
          );
          final background = (ink.decoration! as ShapeDecoration).color!;
          final foregroundLuminance = Color.alphaBlend(
            foreground!,
            background,
          ).computeLuminance();
          final backgroundLuminance = background.computeLuminance();
          final luminances = [foregroundLuminance, backgroundLuminance]..sort();
          expect(
            (luminances.last + .05) / (luminances.first + .05),
            greaterThanOrEqualTo(4.5),
            reason: '$label selected=${chip.selected}',
          );
        }
      }

      expectReadableChips();
      await tester.tap(
        find.widgetWithText(FilterChip, 'Понравилось'),
        kind: PointerDeviceKind.touch,
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, 'Понравилось'))
            .selected,
        isTrue,
      );
      expect(find.text('2 заваривания'), findsOneWidget);
      expectReadableChips();
      await tester.tap(
        find.widgetWithText(FilterChip, 'Все оценки'),
        kind: PointerDeviceKind.touch,
      );
      await tester.pumpAndSettle();
      expect(find.text('3 заваривания'), findsOneWidget);
      expectReadableChips();
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [393.0, 320.0]) {
    testWidgets('Dark screens fit a $width pixel phone', (tester) async {
      phone(tester, width);
      for (final page in <Widget>[
        Home(store: store),
        PackDetail(store: store, packId: 'sidamo'),
        PackEditor(store: store),
        RecipePage(store: store, recipe: store.recipes.first),
        Scaffold(body: Journal(store: store)),
        Scaffold(body: EquipmentPage(store: store)),
        EquipmentEditor(store: store, kit: store.kit),
        ComparePage(store: store, brewIds: ['demo-0', 'demo-2']),
        BrewDetail(store: store, brewId: 'demo-2'),
      ]) {
        await tester.pumpWidget(darkFrame(page));
        await tester.pumpAndSettle();
        expect(
          renderedTheme(tester, find.byType(Scaffold).first).brightness,
          Brightness.dark,
        );
        expect(tester.takeException(), isNull, reason: '${page.runtimeType}');
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('Dark active brewing and result fit a $width pixel phone', (
      tester,
    ) async {
      phone(tester, width);
      store.session = {
        'id': 'dark-layout',
        'recipe': clone(store.recipes.first),
        'started': DateTime.now()
            .subtract(const Duration(seconds: 78))
            .toIso8601String(),
        'state': 'timer',
        'elapsed': 78,
        'sound': false,
      };
      await tester.pumpWidget(darkFrame(TimerPage(store: store)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        renderedTheme(tester, find.byType(TimerPage)).brightness,
        Brightness.dark,
      );
      expect(find.text('Завершить'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.session!['state'] = 'result';
      await tester.pumpWidget(darkFrame(ResultPage(store: store)));
      await tester.pumpAndSettle();
      expect(find.text('Как получилось?'), findsOneWidget);
      expect(
        renderedTheme(tester, find.byType(ResultPage)).brightness,
        Brightness.dark,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
