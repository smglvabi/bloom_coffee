import 'dart:async';

import 'package:bloom/app.dart';
import 'package:bloom/database.dart';
import 'package:bloom/design.dart';
import 'package:bloom/domain.dart';
import 'package:bloom/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DelayedDraftStore extends BloomStore {
  DelayedDraftStore(super.db);
  Completer<void>? nextWrite;

  @override
  Future<void> updateSession(Json data) async {
    final gate = nextWrite;
    nextWrite = null;
    if (gate != null) await gate.future;
    await super.updateSession(data);
  }
}

class FailingDraftStore extends BloomStore {
  FailingDraftStore(super.db);
  bool failWrites = false;
  int writeAttempts = 0;

  @override
  Future<void> updateSession(Json data) async {
    writeAttempts++;
    if (failWrites) throw StateError('Simulated local database write failure');
    await super.updateSession(data);
  }
}

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

  Widget frame(Widget page) => MaterialApp(
    theme: bloomTheme(),
    locale: const Locale('ru'),
    supportedLocales: const [Locale('ru')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: page,
  );

  void phone(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(402, 874);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });
  }

  Finder field(String label) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );

  Future<void> storeChange(
    WidgetTester tester,
    void Function() action,
    bool Function() completed,
  ) async {
    action();
    final deadline = Stopwatch()..start();
    while (!completed() && deadline.elapsed < const Duration(seconds: 10)) {
      // Drain fake-zone continuations and native SQLite work without advancing
      // the 400 ms debounce timer: lifecycle alone must flush the edit.
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }
    expect(completed(), isTrue, reason: 'Local SQLite write completes');
  }

  testWidgets('iOS inactive flushes the latest draft before debounce', (
    tester,
  ) async {
    phone(tester);
    await tester.runAsync(() => store.start(store.recipes.first, manual: true));
    await tester.pumpWidget(frame(ResultPage(store: store)));
    await tester.pumpAndSettle();
    await tester.enterText(field('Заметка о вкусе'), 'Персик и бергамот');
    // Do not advance the fake clock by the 400 ms debounce interval.
    await storeChange(
      tester,
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.inactive,
      ),
      () => store.session?['draft']?['note'] == 'Персик и бергамот',
    );
    final restored = BloomStore(store.db);
    try {
      await tester.runAsync(restored.load);
      expect(restored.session!['draft']['note'], 'Персик и бергамот');
      expect(restored.pack('sidamo')['remaining'], 205);
      expect(restored.brews.length, 3);
    } finally {
      restored.dispose();
    }
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('A pending lifecycle write finishes before saving the cup', (
    tester,
  ) async {
    phone(tester);
    final delayed = DelayedDraftStore(store.db);
    await tester.runAsync(delayed.load);
    await tester.runAsync(
      () => delayed.start(delayed.recipes.first, manual: true),
    );
    final brewId = delayed.session!['id'];
    await tester.pumpWidget(frame(ResultPage(store: delayed)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Понравилось'));
    await tester.enterText(field('Заметка о вкусе'), 'Спелый персик');
    final gate = Completer<void>();
    delayed.nextWrite = gate;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.tap(find.text('Сохранить заваривание'));
    await tester.pump();
    expect(delayed.brews.any((brew) => brew['id'] == brewId), isFalse);
    await storeChange(
      tester,
      gate.complete,
      () => delayed.brews.any((brew) => brew['id'] == brewId),
    );
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(seconds: 1));
    expect(delayed.session, isNull);
    final restored = BloomStore(store.db);
    try {
      await tester.runAsync(restored.load);
      expect(restored.session, isNull);
      final saved = restored.brews.firstWhere((brew) => brew['id'] == brewId);
      expect(saved['note'], 'Спелый персик');
      expect(restored.pack('sidamo')['remaining'], 190);
    } finally {
      restored.dispose();
    }
    await tester.pumpWidget(const SizedBox());
    delayed.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Timer resumes from wall-clock time without a stale cue', (
    tester,
  ) async {
    phone(tester);
    final recipe = clone(store.recipes.first)
      ..['duration'] = 60
      ..['steps'] = [
        {'time': 0, 'water': 45},
        {'time': 1, 'water': 250},
      ];
    store.session = {
      'id': 'resume-timer',
      'recipe': recipe,
      'started': DateTime.now().toIso8601String(),
      'state': 'timer',
      'elapsed': 0,
      'sound': true,
    };
    await tester.pumpWidget(frame(TimerPage(store: store)));
    final before = tester
        .widget<BrewTimerDial>(find.byType(BrewTimerDial))
        .elapsed;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1200)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester.widget<BrewTimerDial>(find.byType(BrewTimerDial)).elapsed,
      before,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    final dial = tester.widget<BrewTimerDial>(find.byType(BrewTimerDial));
    expect(dial.elapsed, greaterThanOrEqualTo(1));
    expect(dial.step, 2);
    // A catch-up audio call would fail without an installed platform player
    // and display the error banner. Resuming must remain silent.
    expect(
      find.text('Звук недоступен. Следите за этапами на экране.'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Save later keeps the latest edit open when draft writing fails', (
    tester,
  ) async {
    phone(tester);
    final failing = FailingDraftStore(store.db);
    await tester.runAsync(failing.load);
    await tester.runAsync(
      () => failing.start(failing.recipes.first, manual: true),
    );
    await tester.pumpWidget(frame(Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => ResultPage(store: failing),
          )),
          child: const Text('Открыть результат'),
        ),
      ),
    )));
    await tester.tap(find.text('Открыть результат'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Заметка о вкусе'), 'Последняя заметка');
    failing.failWrites = true;
    await tester.tap(find.byTooltip('Назад'));
    await storeChange(
      tester,
      () {},
      () => find.text('Сохранить позже').evaluate().isNotEmpty,
    );
    await tester.pumpAndSettle();
    final attemptsBeforeLeaving = failing.writeAttempts;
    await tester.tap(find.text('Сохранить позже'));
    await storeChange(
      tester,
      () {},
      () => failing.writeAttempts > attemptsBeforeLeaving,
    );
    await tester.pumpAndSettle();
    expect(find.byType(ResultPage), findsOneWidget);
    expect(find.text('Открыть результат'), findsNothing);
    expect(
      tester.widget<TextField>(field('Заметка о вкусе')).controller!.text,
      'Последняя заметка',
    );
    expect(
      find.text(
        'Не удалось сохранить черновик. Не закрывайте приложение и попробуйте ещё раз.',
      ),
      findsOneWidget,
    );
    expect(failing.session?['draft'], isNull);

    // Once storage works again, the same screen can retry and leave safely.
    failing.failWrites = false;
    await tester.tap(find.byTooltip('Назад'));
    await storeChange(
      tester,
      () {},
      () => find.text('Сохранить позже').evaluate().isNotEmpty,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить позже'));
    await storeChange(
      tester,
      () {},
      () => find.text('Открыть результат').evaluate().isNotEmpty,
    );
    await tester.pumpAndSettle();
    expect(failing.session!['draft']['note'], 'Последняя заметка');
    final restored = BloomStore(store.db);
    try {
      await tester.runAsync(restored.load);
      expect(restored.session!['draft']['note'], 'Последняя заметка');
    } finally {
      restored.dispose();
    }
    await tester.pumpWidget(const SizedBox());
    failing.dispose();
    expect(tester.takeException(), isNull);
  });
}
