import 'package:bloom/app.dart';
import 'package:bloom/database.dart';
import 'package:bloom/design.dart';
import 'package:bloom/domain.dart';
import 'package:bloom/duration_picker.dart';
import 'package:bloom/store.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  final minutes = find.byKey(const ValueKey('duration-minutes'));
  final seconds = find.byKey(const ValueKey('duration-seconds'));
  final confirm = find.byKey(const ValueKey('duration-confirm'));
  final cancel = find.byKey(const ValueKey('duration-cancel'));

  Widget frame(Widget page, {Brightness brightness = Brightness.light}) =>
      MaterialApp(
        theme: bloomTheme(
          brightness: brightness,
        ).copyWith(platform: TargetPlatform.android),
        locale: const Locale('ru'),
        supportedLocales: const [Locale('ru')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: page,
      );

  void phone(WidgetTester tester, [double width = 320]) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 852);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<TextEditingController> mount(
    WidgetTester tester, {
    String initial = '3:05',
    int minSeconds = 0,
    int maxSeconds = 21600,
    Brightness brightness = Brightness.light,
  }) async {
    phone(tester);
    final controller = TextEditingController(text: initial);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      frame(
        Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                child: DurationField(
                  controller: controller,
                  label: 'Время',
                  minSeconds: minSeconds,
                  maxSeconds: maxSeconds,
                ),
              ),
            ),
          ),
        ),
        brightness: brightness,
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  Future<void> open(WidgetTester tester, [Finder? field]) async {
    final target = field ?? find.byType(DurationField);
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
    expect(minutes, findsOneWidget);
    expect(seconds, findsOneWidget);
    expect(find.text(':'), findsOneWidget);
    expect(tester.testTextInput.isVisible, isFalse);
  }

  Future<void> choose(
    WidgetTester tester, {
    required int minute,
    required int second,
  }) async {
    tester
        .widget<CupertinoPicker>(minutes)
        .scrollController!
        .jumpToItem(minute);
    tester
        .widget<CupertinoPicker>(seconds)
        .scrollController!
        .jumpToItem(second);
    await tester.pumpAndSettle();
  }

  bool canConfirm(WidgetTester tester) =>
      tester.widget<FilledButton>(confirm).onPressed != null;

  Future<void> done(WidgetTester tester) async {
    expect(canConfirm(tester), isTrue);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      'Duration wheels select minutes and seconds without a keyboard at 320px in $brightness',
      (tester) async {
        final controller = await mount(tester, brightness: brightness);
        expect(find.byType(EditableText), findsNothing);
        await open(tester);
        expect(Theme.of(tester.element(minutes)).brightness, brightness);
        await choose(tester, minute: 2, second: 17);
        expect(controller.text, '3:05', reason: 'Selection is still a draft');
        expect(find.byType(EditableText), findsNothing);
        await done(tester);
        expect(controller.text, '2:17');
        expect(find.text('2:17'), findsOneWidget);
        expect(tester.testTextInput.isVisible, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Cancel and back preserve the original duration', (tester) async {
    final controller = await mount(tester);
    await open(tester);
    await choose(tester, minute: 4, second: 50);
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    expect(controller.text, '3:05');
    await open(tester);
    expect(
      tester.widget<CupertinoPicker>(minutes).scrollController!.selectedItem,
      3,
    );
    expect(
      tester.widget<CupertinoPicker>(seconds).scrollController!.selectedItem,
      5,
    );
    await choose(tester, minute: 8, second: 10);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(controller.text, '3:05');
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Recipe duration accepts 30 and 3600 seconds with clear bounds', (
    tester,
  ) async {
    final controller = await mount(tester, minSeconds: 30, maxSeconds: 3600);
    await open(tester);
    await choose(tester, minute: 0, second: 29);
    expect(canConfirm(tester), isFalse);
    expect(find.text('Выберите время в указанном диапазоне.'), findsOneWidget);
    expect(controller.text, '3:05');
    await choose(tester, minute: 0, second: 30);
    await done(tester);
    expect(controller.text, '0:30');

    await open(tester);
    await choose(tester, minute: 60, second: 1);
    expect(canConfirm(tester), isFalse);
    expect(controller.text, '0:30');
    await choose(tester, minute: 60, second: 0);
    await done(tester);
    expect(controller.text, '60:00');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Actual duration accepts zero and the six hour boundary', (
    tester,
  ) async {
    final controller = await mount(tester);
    await open(tester);
    await choose(tester, minute: 0, second: 0);
    await done(tester);
    expect(controller.text, '0:00');
    await open(tester);
    await choose(tester, minute: 360, second: 1);
    expect(canConfirm(tester), isFalse);
    expect(controller.text, '0:00');
    await choose(tester, minute: 360, second: 0);
    await done(tester);
    expect(controller.text, '360:00');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Done immediately after a fling keeps the visible wheel value', (
    tester,
  ) async {
    final controller = await mount(tester, initial: '3:00');
    await open(tester);
    await tester.fling(seconds, const Offset(0, -160), 1200);
    await tester.pump(const Duration(milliseconds: 16));
    final minute = tester
        .widget<CupertinoPicker>(minutes)
        .scrollController!
        .selectedItem;
    final second = tester
        .widget<CupertinoPicker>(seconds)
        .scrollController!
        .selectedItem;
    expect(second, greaterThan(0));
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(controller.text, clock(minute * 60 + second));
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  group('Recipe duration persistence', () {
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

    Finder timeField(String label) => find.byWidgetPredicate(
      (widget) => widget is DurationField && widget.label == label,
    );
    Finder textField(String label) => find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == label,
    );
    List<String> stageTimes(WidgetTester tester) => tester
        .widgetList<DurationField>(timeField('Начало'))
        .map((field) => field.controller.text)
        .toList();

    testWidgets(
      'Picked stage times must increase and survive recipe scaling and SQLite reload',
      (tester) async {
        phone(tester, 393);
        final recipeId = store.recipes.first['id'];
        final original = clone(store.recipes.first);
        final pastBrews = store.brews.map(clone).toList();
        await tester.pumpWidget(
          frame(RecipePage(store: store, recipe: original)),
        );
        await tester.pumpAndSettle();
        await open(tester, timeField('Начало').at(1));
        await choose(tester, minute: 1, second: 20);
        await done(tester);
        await tester.tap(find.byTooltip('Сохранить рецепт'));
        await tester.pumpAndSettle();
        expect(
          find.text(
            'Время этапов должно возрастать и быть меньше общего времени.',
          ),
          findsWidgets,
        );
        expect(store.recipes.first, original);

        await open(tester, timeField('Начало').at(1));
        await choose(tester, minute: 0, second: 50);
        await done(tester);
        await open(tester, timeField('Ориентировочное время'));
        await choose(tester, minute: 4, second: 30);
        await done(tester);
        for (final entry in {'Кофе': '20', 'Вода': '300'}.entries) {
          await tester.ensureVisible(textField(entry.key));
          await tester.enterText(textField(entry.key), entry.value);
          await tester.pump();
        }
        expect(stageTimes(tester), ['0:00', '0:50', '1:15', '1:45']);
        expect(
          tester
              .widget<DurationField>(timeField('Ориентировочное время'))
              .controller
              .text,
          '4:30',
        );

        bool saved() => store.recipes.any(
          (recipe) => recipe['id'] == recipeId && recipe['duration'] == 270,
        );
        await tester.tap(find.byTooltip('Сохранить рецепт'));
        final waiting = Stopwatch()..start();
        while (!saved() && waiting.elapsed < const Duration(seconds: 10)) {
          await tester.pump();
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        }
        expect(saved(), isTrue, reason: 'The recipe must reach SQLite');
        await tester.pumpAndSettle();
        await tester.runAsync(store.load);
        final restored = store.recipes.singleWhere(
          (recipe) => recipe['id'] == recipeId,
        );
        expect(restored['duration'], 270);
        expect(restored['dose'], 20);
        expect(restored['water'], 300);
        expect(
          (restored['steps'] as List).map((step) => step['time']).toList(),
          [0, 50, 75, 105],
        );
        expect(store.brews, pastBrews);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          frame(RecipePage(store: store, recipe: restored)),
        );
        await tester.pumpAndSettle();
        expect(stageTimes(tester), ['0:00', '0:50', '1:15', '1:45']);
        expect(
          tester
              .widget<DurationField>(timeField('Ориентировочное время'))
              .controller
              .text,
          '4:30',
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}
