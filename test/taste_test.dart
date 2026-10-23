import 'dart:convert';

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
    await store.start(store.recipes.first, manual: true);
  });
  tearDown(() async {
    store.dispose();
    await store.db.close();
  });

  Widget frame(Widget page) => MaterialApp(
    theme: bloomTheme(),
    locale: const Locale('ru'),
    supportedLocales: const [Locale('ru')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: page,
  );

  void phone(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> waitForSave(
    WidgetTester tester,
    bool Function() completed,
  ) async {
    final deadline = Stopwatch()..start();
    while (!completed() && deadline.elapsed < const Duration(seconds: 10)) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }
    expect(completed(), isTrue, reason: 'Local SQLite write completes');
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Bitterness works in an old draft and survives draft, history and export',
    (tester) async {
      phone(tester);
      final brewId = store.session!['id'];
      final oldHistory = jsonEncode(store.brews);
      await tester.runAsync(
        () => store.updateSession(
          clone(store.session!)
            ..['draft'] = {
              'taste': {'Кислотность': 2.0, 'Сладость': 4.0, 'Тело': 3.0},
              'tasteChanged': true,
            },
        ),
      );
      await tester.pumpWidget(frame(ResultPage(store: store)));
      await tester.pumpAndSettle();
      final list = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('Подробнее о вкусе'),
        250,
        scrollable: list,
      );
      await tester.tap(find.text('Подробнее о вкусе'));
      await tester.pumpAndSettle();
      final bitterness = find.byKey(const ValueKey('taste-Горечь'));
      await tester.scrollUntilVisible(bitterness, 200, scrollable: list);
      expect(tester.widget<Slider>(bitterness).value, 3);
      expect(
        tester
            .widget<Slider>(find.byKey(const ValueKey('taste-Кислотность')))
            .value,
        2,
      );
      final sliderBounds = tester.getRect(bitterness);
      await tester.tapAt(
        Offset(sliderBounds.right - 24, sliderBounds.center.dy),
      );
      await tester.pump();
      expect(tester.widget<Slider>(bitterness).value, 5);
      await waitForSave(
        tester,
        () => store.session?['draft']?['taste']?['Горечь'] == 5,
      );

      final restoredDraft = BloomStore(store.db);
      try {
        await tester.runAsync(restoredDraft.load);
        expect(restoredDraft.session!['draft']['taste']['Горечь'], 5);
        expect(restoredDraft.session!['draft']['taste']['Кислотность'], 2);
      } finally {
        restoredDraft.dispose();
      }

      await tester.scrollUntilVisible(
        find.text('Понравилось'),
        -250,
        scrollable: list,
      );
      await tester.tap(find.text('Понравилось'));
      await tester.tap(find.text('Сохранить заваривание'));
      await waitForSave(
        tester,
        () => store.brews.any((brew) => brew['id'] == brewId),
      );
      final saved = store.brews.firstWhere((brew) => brew['id'] == brewId);
      expect(saved['taste']['Горечь'], 5);
      expect(saved['taste']['Кислотность'], 2);
      expect(store.pack('sidamo')['remaining'], 190);
      expect(
        jsonEncode(store.brews.where((brew) => brew['id'] != brewId).toList()),
        oldHistory,
      );
      final exported = jsonDecode(store.exportJson()) as Map;
      final exportedBrew = (exported['brews'] as List).firstWhere(
        (brew) => brew['id'] == brewId,
      );
      expect(exportedBrew['taste']['Горечь'], 5);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(frame(BrewDetail(store: store, brewId: brewId)));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Горечь'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Горечь'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Taste stays optional when its sliders are not changed', (
    tester,
  ) async {
    phone(tester);
    final brewId = store.session!['id'];
    await tester.pumpWidget(frame(ResultPage(store: store)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Нормально'));
    await tester.tap(find.text('Сохранить заваривание'));
    await waitForSave(
      tester,
      () => store.brews.any((brew) => brew['id'] == brewId),
    );
    expect(
      store.brews.firstWhere((brew) => brew['id'] == brewId)['taste'],
      isEmpty,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
