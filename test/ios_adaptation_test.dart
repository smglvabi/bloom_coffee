import 'package:bloom/app.dart';
import 'package:bloom/database.dart';
import 'package:bloom/design.dart';
import 'package:bloom/platform_keyboard.dart';
import 'package:bloom/store.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS);
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  testWidgets('iPhone number keyboard has Done and leaves controls visible', (
    tester,
  ) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    double? reservedInset;
    await tester.pumpWidget(
      MaterialApp(
        theme: bloomTheme(),
        builder: (context, child) => MediaQuery(
          data: const MediaQueryData(
            size: Size(402, 874),
            viewInsets: EdgeInsets.only(bottom: 300),
          ),
          child: IosKeyboardAccessory(child: child!),
        ),
        home: Builder(
          builder: (context) {
            reservedInset = MediaQuery.viewInsetsOf(context).bottom;
            return Scaffold(
              body: TextField(
                focusNode: focus,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(focus.hasFocus, isTrue);
    expect(reservedInset, 344);
    final done = find.byKey(const ValueKey('ios-keyboard-done'));
    expect(done, findsOneWidget);
    await tester.tap(done);
    await tester.pumpAndSettle();
    expect(focus.hasFocus, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('iPhone 16 Pro keeps ongoing-session content above home indicator', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(402, 874);
    tester.view.padding = const FakeViewPadding(top: 62, bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(top: 62, bottom: 34);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    final store = (await tester.runAsync(() async {
      final store = BloomStore(
        await openBloomDatabase(
          factoryOverride: databaseFactoryFfi,
          path: inMemoryDatabasePath,
        ),
      );
      await store.load();
      await store.start(store.recipes.first);
      return store;
    }))!;
    addTearDown(() async {
      store.dispose();
      await store.db.close();
    });
    await tester.pumpWidget(BloomApp(store: store));
    await tester.pumpAndSettle();
    final content = tester.getRect(find.byType(IndexedStack).first);
    expect(content.top, greaterThanOrEqualTo(62));
    expect(content.bottom, lessThanOrEqualTo(840));
    expect(find.text('Заваривание продолжается'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('iOS confirmation uses native actions and returns cancellation', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: bloomTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await confirm(
                  context,
                  title: 'Архивировать пачку?',
                  message: 'История завариваний сохранится.',
                );
              },
              child: const Text('Открыть'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    await tester.tap(find.text('Назад'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('iPhone standalone forms and details remain usable at 130% text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(402, 874);
    tester.view.padding = const FakeViewPadding(top: 62, bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(top: 62, bottom: 34);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    final store = (await tester.runAsync(() async {
      final store = BloomStore(
        await openBloomDatabase(
          factoryOverride: databaseFactoryFfi,
          path: inMemoryDatabasePath,
        ),
      );
      await store.load();
      return store;
    }))!;
    addTearDown(() async {
      store.dispose();
      await store.db.close();
    });

    for (final (page, lastContent) in <(Widget, Finder)>[
      (
        PackEditor(store: store),
        find.widgetWithText(FilledButton, 'Сохранить пачку'),
      ),
      (
        EquipmentEditor(store: store),
        find.widgetWithText(FilledButton, 'Сохранить набор'),
      ),
      (
        PackDetail(store: store, packId: 'sidamo'),
        find.widgetWithText(InfoRow, 'Открыта'),
      ),
      (
        BrewDetail(store: store, brewId: 'demo-2'),
        find.widgetWithText(OutlinedButton, 'Сравнить с другой чашкой'),
      ),
      (
        ComparePage(store: store, brewIds: ['demo-0', 'demo-2']),
        find.text(
          'Сравнивайте параметры и свои впечатления. Причины изменения вкуса остаются вашим наблюдением.',
        ),
      ),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: bloomTheme(),
          locale: const Locale('ru'),
          supportedLocales: const [Locale('ru')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.3),
            ),
            child: IosKeyboardAccessory(child: child!),
          ),
          home: page,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '${page.runtimeType}');
      final scrollable = find.descendant(
        of: find.byType(ListView).first,
        matching: find.byType(Scrollable),
      ).first;
      await tester.scrollUntilVisible(
        lastContent,
        300,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();
      final position = tester.state<ScrollableState>(scrollable).position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      final bounds = tester.getRect(lastContent);
      expect(bounds.top, greaterThanOrEqualTo(118), reason: '${page.runtimeType}');
      expect(bounds.bottom, lessThanOrEqualTo(840), reason: '${page.runtimeType}');
      if (page is PackEditor ||
          page is EquipmentEditor ||
          page is BrewDetail) {
        expect(lastContent.hitTestable(), findsOneWidget);
      }
      expect(tester.takeException(), isNull, reason: '${page.runtimeType}');
      await tester.pumpWidget(const SizedBox());
    }
  });
}
