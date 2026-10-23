import 'package:bloom/app.dart';
import 'package:bloom/database.dart';
import 'package:bloom/design.dart';
import 'package:bloom/domain.dart';
import 'package:bloom/store.dart';
import 'package:flutter/material.dart';
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

  final picker = find.byKey(const ValueKey('journal-pack-picker'));
  Finder option(String id) => find.byKey(ValueKey('journal-pack-option-$id'));

  Future<void> mount(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
    double width = 393,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 852);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: bloomTheme(brightness: brightness),
        locale: const Locale('ru'),
        supportedLocales: const [Locale('ru')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(body: Journal(store: store)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester) async {
    await tester.ensureVisible(picker);
    await tester.tap(picker);
    await tester.pumpAndSettle();
    expect(find.text('Выбор пачки'), findsOneWidget);
  }

  Future<void> choose(WidgetTester tester, String id) async {
    await open(tester);
    await tester.tap(option(id));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
  }

  void expectField(String name) {
    expect(
      find.descendant(of: picker, matching: find.text(name)),
      findsOneWidget,
    );
  }

  testWidgets(
    'Pack selection filters history while keeping the rating filter',
    (tester) async {
      final packsBefore = store.packs.map(clone).toList();
      final brewsBefore = store.brews.map(clone).toList();
      await mount(tester);
      await tester.tap(find.widgetWithText(FilterChip, 'Понравилось'));
      await tester.pumpAndSettle();
      expect(find.text('2 заваривания'), findsOneWidget);

      await choose(tester, 'huila');
      expectField('Колумбия Уила');
      expect(find.byType(BrewTile), findsNothing);
      expect(
        find.text('По выбранным фильтрам ничего не найдено.'),
        findsOneWidget,
      );

      await choose(tester, 'all');
      expectField('Все пачки');
      expect(find.text('2 заваривания'), findsOneWidget);
      expect(
        tester
            .widgetList<BrewTile>(find.byType(BrewTile))
            .map((tile) => tile.brew['rating']),
        everyElement('Понравилось'),
      );
      await choose(tester, 'sidamo');
      expectField('Эфиопия Сидамо');
      expect(find.text('2 заваривания'), findsOneWidget);
      expect(store.packs, packsBefore);
      expect(store.brews, brewsBefore);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Changing the pack clears comparison selection', (tester) async {
    await mount(tester);
    await tester.tap(find.byTooltip('Выбрать для сравнения'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.text('Сравнить · 1 из 2'), findsOneWidget);

    await choose(tester, 'sidamo');
    expect(find.text('Сравнить · 0 из 2'), findsOneWidget);
    expect(
      tester
          .widgetList<BrewTile>(find.byType(BrewTile))
          .map((tile) => tile.selected),
      everyElement(false),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Close, back and outside dismissal keep the filter and selection',
    (tester) async {
      await mount(tester);
      await choose(tester, 'sidamo');
    await tester.scrollUntilVisible(
      find.byTooltip('Выбрать для сравнения'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
      await tester.tap(find.byTooltip('Выбрать для сравнения'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();

      for (final dismiss in ['close', 'back', 'outside']) {
        await open(tester);
        if (dismiss == 'close') {
          await tester.tap(find.byTooltip('Закрыть выбор пачки'));
        } else if (dismiss == 'back') {
          await tester.binding.handlePopRoute();
        } else {
          expect(tester.getRect(find.byType(BottomSheet)).top, greaterThan(8));
          await tester.tapAt(const Offset(8, 8));
        }
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing, reason: dismiss);
        expectField('Эфиопия Сидамо');
        expect(find.text('Сравнить · 1 из 2'), findsOneWidget, reason: dismiss);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('An empty library still offers All packs', (tester) async {
    store.packs = [];
    store.brews = [];
    await mount(tester, width: 320);
    await open(tester);
    expect(option('all'), findsOneWidget);
    expect(find.byType(CoffeeCover), findsNothing);
    await tester.tap(option('all'));
    await tester.pumpAndSettle();
    expectField('Все пачки');
    expect(find.text('Здесь будут ваши чашки'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets('Pack sheet fits 320px with long names and $brightness colors', (
      tester,
    ) async {
      for (var i = 0; i < 14; i++) {
        store.packs.add(
          clone(store.packs.first)
            ..['id'] = 'long-$i'
            ..['name'] =
                'Эфиопия — экспериментальная микропартия с высокогорной станции $i'
            ..['roaster'] =
                'Маленькая обжарочная мастерская у Северного склона',
        );
      }
      await mount(tester, brightness: brightness, width: 320);
      await choose(tester, 'sidamo');
      await open(tester);
      final colors = brightness == Brightness.dark
          ? BloomColors.dark
          : BloomColors.light;
      expect(
        tester.widget<BottomSheet>(find.byType(BottomSheet)).backgroundColor,
        colors.bg,
      );
      expect(
        find.descendant(
          of: option('sidamo'),
          matching: find.byIcon(Icons.check),
        ),
        findsOneWidget,
      );
      for (final id in ['all', 'sidamo', 'huila']) {
        final row = option(id);
        final background = tester.widget<Material>(row).color!;
        for (final text in tester.widgetList<Text>(
          find.descendant(of: row, matching: find.byType(Text)),
        )) {
          final foreground = text.style!.color!;
          final luminances = [
            Color.alphaBlend(foreground, background).computeLuminance(),
            background.computeLuminance(),
          ]..sort();
          expect(
            (luminances.last + .05) / (luminances.first + .05),
            greaterThanOrEqualTo(4.5),
            reason: '${text.data} in $brightness',
          );
        }
      }
      expect(tester.takeException(), isNull);
      final sheetScroll = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        option('long-13'),
        350,
        scrollable: sheetScroll.first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(option('long-13'));
      await tester.pumpAndSettle();
      expectField(store.packs.last['name']);
      expect(find.byType(BottomSheet), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
