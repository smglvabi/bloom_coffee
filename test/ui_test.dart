import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:bloom/app.dart';
import 'package:bloom/database.dart';
import 'package:bloom/design.dart';
import 'package:bloom/domain.dart';
import 'package:bloom/duration_picker.dart';
import 'package:bloom/store.dart';

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
  void phone(WidgetTester tester, double width) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 852);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Finder field(String label) => find.byWidgetPredicate(
    (w) =>
        (w is TextField && w.decoration?.labelText == label) ||
        (w is DurationField && w.label == label),
  );
  String controllerValue(Widget widget) => widget is DurationField
      ? widget.controller.text
      : (widget as TextField).controller!.text;
  String fieldValue(WidgetTester tester, String label) =>
      controllerValue(tester.widget(field(label)));
  List<String> fieldValues(WidgetTester tester, String label) =>
      tester.widgetList<Widget>(field(label)).map(controllerValue).toList();
  Future<void> saveAndWait(
    WidgetTester tester,
    Finder action,
    bool Function() isSaved,
  ) async {
    await tester.runAsync(() async {
      final saved = Completer<void>();
      void onChanged() {
        if (isSaved() && !saved.isCompleted) saved.complete();
      }

      store.addListener(onChanged);
      try {
        await tester.tap(action);
        onChanged();
        await saved.future.timeout(const Duration(seconds: 10));
      } finally {
        store.removeListener(onChanged);
      }
    });
    await tester.pumpAndSettle();
  }

  testWidgets('Home tabs and all main screens fit 393 and 320 pixel phones', (
    tester,
  ) async {
    phone(tester, 393);
    for (final width in [393.0, 320.0]) {
      tester.view.physicalSize = Size(width, 852);
      for (final page in <Widget>[
        Home(store: store),
        PackDetail(store: store, packId: 'sidamo'),
        PackEditor(store: store),
        RecipePage(store: store, recipe: store.recipes.first),
        Scaffold(body: Journal(store: store)),
        Scaffold(body: EquipmentPage(store: store)),
        ComparePage(store: store, brewIds: ['demo-0', 'demo-2']),
        BrewDetail(store: store, brewId: 'demo-2'),
      ]) {
        await tester.pumpWidget(frame(page));
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '${page.runtimeType} at $width',
        );
        await tester.pumpWidget(const SizedBox());
      }
    }
  });
  for (final systemBrightness in Brightness.values) {
    testWidgets(
      'Android journal chip labels keep contrast and filter with $systemBrightness',
      (tester) async {
        phone(tester, 393);
        tester.platformDispatcher.platformBrightnessTestValue =
            systemBrightness;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        await tester.pumpWidget(
          MaterialApp(
            theme: bloomTheme().copyWith(platform: TargetPlatform.android),
            locale: const Locale('ru'),
            supportedLocales: const [Locale('ru')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: Scaffold(body: Journal(store: store)),
          ),
        );
        await tester.pumpAndSettle();

        void expectReadableLabels() {
          final chips = find.byType(FilterChip);
          expect(chips, findsNWidgets(4));
          for (var i = 0; i < 4; i++) {
            final chip = chips.at(i);
            final label = tester.widget<FilterChip>(chip).label as Text;
            final paragraph = tester.renderObject<RenderParagraph>(
              find.descendant(of: chip, matching: find.byType(RichText)),
            );
            final style = paragraph.text.style;
            final foreground = style?.foreground?.color ?? style?.color;
            // An unresolved color paints white in the native text renderer.
            expect(foreground, isNotNull, reason: '${label.data}: text paint');
            final ink = tester.widget<Ink>(
              find.descendant(of: chip, matching: find.byType(Ink)),
            );
            final background = (ink.decoration! as ShapeDecoration).color!;
            final textLuminance = Color.alphaBlend(
              foreground!,
              background,
            ).computeLuminance();
            final backgroundLuminance = background.computeLuminance();
            final lighter = textLuminance > backgroundLuminance
                ? textLuminance
                : backgroundLuminance;
            final darker = textLuminance < backgroundLuminance
                ? textLuminance
                : backgroundLuminance;
            expect(
              (lighter + .05) / (darker + .05),
              greaterThanOrEqualTo(4.5),
              reason: '${label.data}: text contrast',
            );
          }
        }

        expectReadableLabels();
        expect(find.text('3 заваривания'), findsOneWidget);
        await tester.tap(
          find.widgetWithText(FilterChip, 'Понравилось'),
          kind: PointerDeviceKind.touch,
        );
        await tester.pumpAndSettle();
        expectReadableLabels();
        expect(find.text('2 заваривания'), findsOneWidget);
        expect(find.byType(BrewTile), findsNWidgets(2));
        expect(
          tester
              .widgetList<BrewTile>(find.byType(BrewTile))
              .map((w) => w.brew['rating']),
          everyElement('Понравилось'),
        );
        await tester.tap(
          find.widgetWithText(FilterChip, 'Все оценки'),
          kind: PointerDeviceKind.touch,
        );
        await tester.pumpAndSettle();
        expectReadableLabels();
        expect(find.text('3 заваривания'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('Recipe form rescales dose and water, keeping the time', (
    tester,
  ) async {
    phone(tester, 393);
    await tester.pumpWidget(
      frame(RecipePage(store: store, recipe: store.recipes.first)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(field('Кофе'), '2');
    await tester.enterText(field('Кофе'), '20');
    await tester.pump();
    expect(fieldValue(tester, 'Вода'), '333');
    expect(fieldValue(tester, 'Пропорция'), '16,7');
    await tester.enterText(field('Вода'), '300');
    await tester.pump();
    expect(fieldValue(tester, 'Пропорция'), '15');
    await tester.scrollUntilVisible(
      field('Ориентировочное время'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(fieldValue(tester, 'Ориентировочное время'), '3:00');
    final targets = tester
        .widgetList<TextField>(field('Влить до'))
        .map((w) => w.controller!.text);
    expect(targets.last, '300');
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Direct ratio input rescales pours and keeps precise dose scaling',
    (tester) async {
      phone(tester, 393);
      await tester.pumpWidget(
        frame(RecipePage(store: store, recipe: store.recipes.first)),
      );
      await tester.pumpAndSettle();
      expect(fieldValue(tester, 'Пропорция'), '16,7');
      expect(
        tester.widget<TextField>(field('Пропорция')).decoration!.prefixText,
        '1:',
      );
      final times = fieldValues(tester, 'Начало');
      await tester.enterText(field('Пропорция'), '16');
      await tester.pump();
      expect(fieldValue(tester, 'Вода'), '240');
      expect(fieldValues(tester, 'Влить до'), ['43', '120', '187', '240']);
      for (final input in ['16.5', '16,5']) {
        await tester.enterText(field('Пропорция'), input);
        await tester.pump();
        expect(fieldValue(tester, 'Вода'), '248', reason: input);
        expect(fieldValues(tester, 'Влить до'), ['45', '124', '193', '248']);
      }
      await tester.enterText(field('Кофе'), '20');
      await tester.pump();
      expect(fieldValue(tester, 'Вода'), '330');
      expect(fieldValue(tester, 'Пропорция'), '16,5');
      expect(fieldValues(tester, 'Влить до'), ['59', '165', '257', '330']);
      expect(fieldValues(tester, 'Начало'), times);
      expect(fieldValue(tester, 'Ориентировочное время'), '3:00');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Invalid ratios neither rescale the plan nor save the recipe', (
    tester,
  ) async {
    phone(tester, 393);
    final original = clone(store.recipes.first);
    await tester.pumpWidget(frame(RecipePage(store: store, recipe: original)));
    await tester.pumpAndSettle();
    await tester.enterText(
      field('Название рецепта'),
      'Несохранённое изменение',
    );
    final originalWater = fieldValue(tester, 'Вода');
    final originalPours = fieldValues(tester, 'Влить до');
    for (final input in ['', 'NaN', '0', 'Infinity', '150', '0,1']) {
      await tester.enterText(field('Пропорция'), input);
      await tester.pump();
      expect(fieldValue(tester, 'Вода'), originalWater, reason: input);
      expect(fieldValues(tester, 'Влить до'), originalPours, reason: input);
      await tester.tap(find.byTooltip('Сохранить рецепт'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(field('Пропорция')).decoration!.errorText,
        isNotEmpty,
        reason: input,
      );
      expect(store.recipes.first, original, reason: input);
    }
    expect(store.session, isNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Ratio waits for a valid dose and uses only dose and water limits',
    (tester) async {
      phone(tester, 393);
      await tester.pumpWidget(
        frame(RecipePage(store: store, recipe: store.recipes.first)),
      );
      await tester.pumpAndSettle();
      final originalPours = fieldValues(tester, 'Влить до');
      await tester.enterText(field('Кофе'), '');
      await tester.enterText(field('Пропорция'), '16,5');
      await tester.pump();
      expect(fieldValue(tester, 'Вода'), '250');
      expect(fieldValues(tester, 'Влить до'), originalPours);
      await tester.enterText(field('Кофе'), '20');
      await tester.pump();
      expect(fieldValue(tester, 'Вода'), '330');
      expect(fieldValues(tester, 'Влить до').last, '330');

      // A ratio outside 5..30 is valid when the resulting water is in range.
      await tester.enterText(field('Пропорция'), '40');
      await tester.pump();
      expect(fieldValue(tester, 'Вода'), '800');
      expect(fieldValues(tester, 'Влить до').last, '800');
      expect(tester.state<FormState>(find.byType(Form)).validate(), isTrue);
      await tester.enterText(field('Пропорция'), '2');
      await tester.pump();
      expect(fieldValue(tester, 'Вода'), '40');
      expect(fieldValues(tester, 'Влить до'), ['7', '20', '31', '40']);
      expect(tester.state<FormState>(find.byType(Form)).validate(), isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Edited ratio survives saving without changing past brews', (
    tester,
  ) async {
    phone(tester, 393);
    final recipeId = store.recipes.first['id'];
    final previousBrews = store.brews.map(clone).toList();
    await tester.pumpWidget(
      frame(RecipePage(store: store, recipe: store.recipes.first)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(field('Пропорция'), '16,5');
    await tester.enterText(field('Кофе'), '20');
    await saveAndWait(
      tester,
      find.byTooltip('Сохранить рецепт'),
      () => store.recipes.any((r) => r['id'] == recipeId && r['water'] == 330),
    );
    expect(find.text('Рецепт сохранён для этой пачки'), findsOneWidget);
    await tester.runAsync(store.load);
    final saved = store.recipes.singleWhere((r) => r['id'] == recipeId);
    expect(saved['dose'], 20);
    expect(saved['water'], 330);
    expect(saved['duration'], 180);
    expect((saved['steps'] as List).map((s) => s['water']).toList(), [
      59,
      165,
      257,
      330,
    ]);
    expect(store.brews, previousBrews);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(frame(RecipePage(store: store, recipe: saved)));
    await tester.pumpAndSettle();
    expect(fieldValue(tester, 'Кофе'), '20');
    expect(fieldValue(tester, 'Вода'), '330');
    expect(fieldValue(tester, 'Пропорция'), '16,5');
    expect(fieldValues(tester, 'Влить до'), ['59', '165', '257', '330']);
    expect(fieldValues(tester, 'Начало'), ['0:00', '0:45', '1:15', '1:45']);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Rounded ratio display does not reject water at the upper limit',
    (tester) async {
      phone(tester, 393);
      await tester.pumpWidget(
        frame(RecipePage(store: store, recipe: store.recipes.first)),
      );
      await tester.pumpAndSettle();
      await tester.enterText(field('Кофе'), '87');
      await tester.enterText(field('Вода'), '2000');
      await tester.pump();
      expect(
        double.parse(fieldValue(tester, 'Пропорция').replaceAll(',', '.')),
        23,
      );
      expect(fieldValue(tester, 'Вода'), '2000');
      expect(fieldValues(tester, 'Влить до').last, '2000');
      expect(tester.state<FormState>(find.byType(Form)).validate(), isTrue);
      await tester.enterText(field('Кофе'), '80');
      await tester.pump();
      expect(fieldValue(tester, 'Вода'), '1839');
      expect(fieldValues(tester, 'Влить до').last, '1839');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Manual water waits for dose unless a later ratio takes priority',
    (tester) async {
      phone(tester, 393);
      await tester.pumpWidget(
        frame(RecipePage(store: store, recipe: store.recipes.first)),
      );
      await tester.pumpAndSettle();
      await tester.enterText(field('Кофе'), '');
      await tester.enterText(field('Вода'), '300');
      await tester.enterText(field('Кофе'), '20');
      await tester.pump();
      expect(fieldValue(tester, 'Вода'), '300');
      expect(fieldValue(tester, 'Пропорция'), '15');
      expect(fieldValues(tester, 'Влить до'), ['54', '150', '234', '300']);
      await tester.enterText(field('Кофе'), '');
      await tester.enterText(field('Вода'), '400');
      await tester.enterText(field('Пропорция'), '16');
      await tester.pump();
      expect(fieldValue(tester, 'Вода'), '400');
      await tester.enterText(field('Кофе'), '20');
      await tester.pump();
      expect(fieldValue(tester, 'Вода'), '320');
      expect(fieldValue(tester, 'Пропорция'), '16');
      expect(fieldValues(tester, 'Влить до'), ['58', '160', '250', '320']);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Required pack fields show understandable errors', (
    tester,
  ) async {
    phone(tester, 393);
    await tester.pumpWidget(frame(PackEditor(store: store)));
    await tester.pumpAndSettle();
    await tester.enterText(field('Масса пачки'), '-20');
    await tester.scrollUntilVisible(
      find.text('Сохранить пачку'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Сохранить пачку'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      field('Название зерна'),
      -250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Заполните это поле'), findsOneWidget);
    expect(find.text('Введите число от 1 до 10000'), findsOneWidget);
    expect(store.packs.length, 2);
  });
  testWidgets(
    'Manual result saves from the fixed action bar and consumes the actual dose',
    (tester) async {
      phone(tester, 393);
      store.session = {
        'id': 'ui-save',
        'recipe': clone(store.recipes.first),
        'started': DateTime.now().toIso8601String(),
        'state': 'result',
        'elapsed': 180,
        'sound': false,
      };
      await tester.pumpWidget(frame(ResultPage(store: store)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Понравилось'));
      await tester.enterText(field('Кофе'), '16');
      await saveAndWait(
        tester,
        find.text('Сохранить заваривание'),
        () => store.brews.any((b) => b['id'] == 'ui-save'),
      );
      expect(store.pack('sidamo')['remaining'], 189);
      expect(store.brews.length, 4);
      expect(store.brews.first['recipe']['dose'], 16);
      expect(store.brews.first['rating'], 'Понравилось');
      expect(find.text('Хороший момент\nсохранён.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Active timer and result screen fit a narrow phone', (
    tester,
  ) async {
    phone(tester, 320);
    store.session = {
      'id': 'ui-session',
      'recipe': clone(store.recipes.first),
      'started': DateTime.now()
          .subtract(const Duration(seconds: 200))
          .toIso8601String(),
      'state': 'timer',
      'elapsed': 200,
      'sound': false,
    };
    await tester.pumpWidget(frame(TimerPage(store: store)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Чашка почти готова'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(frame(ResultPage(store: store)));
    await tester.pumpAndSettle();
    expect(find.text('Как получилось?'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
