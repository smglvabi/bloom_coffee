part of '../app.dart';

class StepFields {
  final TextEditingController time, water;
  StepFields(Json step)
    : time = TextEditingController(text: clock(step['time'])),
      water = TextEditingController(text: amount(step['water']));
  void dispose() {
    time.dispose();
    water.dispose();
  }
}

int? parseTime(String value) {
  final match = RegExp(r'^(\d{1,3}):([0-5]\d)$').firstMatch(value.trim());
  return match == null
      ? null
      : int.parse(match[1]!) * 60 + int.parse(match[2]!);
}

class RecipePage extends StatefulWidget {
  final BloomStore store;
  final Json recipe;
  final bool isNew;
  const RecipePage({
    super.key,
    required this.store,
    required this.recipe,
    this.isNew = false,
  });
  @override
  State<RecipePage> createState() => _RecipePageState();
}

class _RecipePageState extends State<RecipePage> {
  final f = FormFields();
  final form = GlobalKey<FormState>();
  late final List<StepFields> steps;
  late Json draft;
  late double previousWater;
  late double targetRatio;
  late final List<double> fractions;
  bool busy = false;
  bool waterAwaitingDose = false;
  String? stepError;
  @override
  void initState() {
    super.initState();
    draft = clone(widget.recipe);
    if (widget.isNew) draft['id'] = uid();
    for (final key in [
      'name',
      'grinder',
      'grind',
      'unit',
      'dripper',
      'filter',
      'brewWater',
    ]) {
      f.c(key, draft[key] ?? '');
    }
    for (final key in ['dose', 'water', 'temperature']) {
      f.c(key, amount(draft[key]));
    }
    f.c('duration', clock(draft['duration']));
    previousWater = number(draft['water']);
    targetRatio = previousWater / number(draft['dose']);
    f.c('ratio', amount(targetRatio));
    fractions = (draft['steps'] as List)
        .map((s) => number(s['water']) / previousWater)
        .toList();
    steps = (draft['steps'] as List).map((s) => StepFields(s)).toList();
  }

  @override
  void dispose() {
    f.dispose();
    for (final s in steps) {
      s.dispose();
    }
    super.dispose();
  }

  void scaleWater(double water) {
    for (var i = 0; i < steps.length; i++) {
      steps[i].water.text = amount(
        i == steps.length - 1 ? water : (fractions[i] * water).round(),
      );
    }
    previousWater = water;
  }

  double? positiveNumber(String value) {
    final n = double.tryParse(value.trim().replaceAll(',', '.'));
    return n != null && n.isFinite && n > 0 ? n : null;
  }

  double? currentDose() {
    final dose = positiveNumber(f.text('dose'));
    return dose != null && dose >= 1 && dose <= 100 ? dose : null;
  }

  double? validWater(String value) {
    final water = positiveNumber(value);
    return water != null &&
            water >= 10 &&
            water <= 2000 &&
            water == water.roundToDouble()
        ? water
        : null;
  }

  double? waterFromRatio(double dose) {
    final water = targetRatio * dose;
    if (!water.isFinite) return null;
    final rounded = water.roundToDouble();
    return rounded >= 10 && rounded <= 2000 ? rounded : null;
  }

  void applyRatio(double dose) {
    final water = waterFromRatio(dose);
    if (water == null) return;
    f.c('water').text = amount(water);
    scaleWater(water);
  }

  void doseChanged(String value) {
    final dose = currentDose();
    if (dose != null) {
      if (waterAwaitingDose) {
        final water = validWater(f.text('water'));
        if (water != null) {
          targetRatio = water / dose;
          f.c('ratio').text = amount(targetRatio);
          waterAwaitingDose = false;
        }
      } else if (positiveNumber(f.text('ratio')) != null) {
        applyRatio(dose);
      }
    }
    setState(() {});
  }

  void waterChanged(String value) {
    final water = validWater(value);
    if (water != null) {
      scaleWater(water);
      final dose = currentDose();
      waterAwaitingDose = dose == null;
      if (dose != null) {
        targetRatio = water / dose;
        f.c('ratio').text = amount(targetRatio);
      }
    }
    setState(() {});
  }

  void ratioChanged(String value) {
    waterAwaitingDose = false;
    final ratio = positiveNumber(value);
    if (ratio != null) {
      targetRatio = ratio;
      final dose = currentDose();
      if (dose != null) applyRatio(dose);
    }
    setState(() {});
  }

  String? ratioError(String? value) {
    if (positiveNumber(value ?? '') == null) {
      return 'Введите число больше 0';
    }
    final dose = currentDose();
    // Keep the exact ratio: its displayed value is rounded to one decimal.
    if (dose != null && waterFromRatio(dose) == null) {
      return 'Вода должна быть от 10 до 2000 г';
    }
    return null;
  }

  Json? read() {
    if (!form.currentState!.validate()) return null;
    final targets = [
      for (final s in steps)
        {
          'time': parseTime(s.time.text)!,
          'water': double.parse(s.water.text.replaceAll(',', '.')),
        },
    ];
    final error = validateSteps(
      targets,
      f.n('water'),
      parseTime(f.text('duration'))!,
    );
    setState(() => stepError = error);
    if (error != null) {
      toast(context, error);
      return null;
    }
    final result = clone(draft);
    for (final key in [
      'name',
      'grinder',
      'grind',
      'unit',
      'dripper',
      'filter',
      'brewWater',
    ]) {
      result[key] = f.text(key);
    }
    for (final key in ['dose', 'water', 'temperature']) {
      result[key] = f.n(key);
    }
    result['steps'] = targets;
    result['duration'] = parseTime(f.text('duration'))!;
    return result;
  }

  Future<void> saveRecipe() async {
    final r = read();
    if (r == null || busy) return;
    setState(() => busy = true);
    await guard(context, () async {
      await widget.store.saveRecipe(r);
      draft = clone(r);
      if (mounted) toast(context, 'Рецепт сохранён для этой пачки');
    });
    if (mounted) setState(() => busy = false);
  }

  Future<void> start(bool manual) async {
    final r = read();
    if (r == null || busy) return;
    if (widget.store.session != null) {
      resumeSession(context, widget.store);
      return;
    }
    setState(() => busy = true);
    await guard(context, () async {
      if (!await checkStock(context, widget.store, r) || !mounted) return;
      await widget.store.start(r, manual: manual);
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => manual
                ? ResultPage(store: widget.store)
                : TimerPage(store: widget.store),
          ),
        );
      }
    });
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Рецепт и подготовка'),
        actions: [
          IconButton(
            onPressed: busy ? null : saveRecipe,
            tooltip: 'Сохранить рецепт',
            icon: const Icon(Icons.bookmark_border),
          ),
        ],
      ),
      body: Form(
        key: form,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.store.pack(draft['packId'])['name'],
                style: TextStyle(color: context.colors.muted, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Text(
                'Ваша следующая чашка',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 24),
              f.field('name', 'Название рецепта', required: true),
              Row(
                children: [
                  const Icon(Icons.filter_alt_outlined, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'V60',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  Text(
                    'МЕТОД ЗАВАРИВАНИЯ',
                    style: TextStyle(
                      color: context.colors.muted,
                      fontSize: 9,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              const SectionLabel('Основа рецепта'),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: f.field(
                      'dose',
                      'Кофе',
                      numeric: true,
                      required: true,
                      min: 1,
                      max: 100,
                      suffix: 'г',
                      onChanged: doseChanged,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: f.field(
                      'water',
                      'Вода',
                      numeric: true,
                      required: true,
                      min: 10,
                      max: 2000,
                      suffix: 'г',
                      integer: true,
                      onChanged: waterChanged,
                    ),
                  ),
                ],
              ),
              TextFormField(
                controller: f.c('ratio'),
                style: mono(16),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: InputDecoration(
                  labelText: 'Пропорция',
                  prefixText: '1:',
                  prefixStyle: mono(16),
                  hintText: '16,7',
                  errorMaxLines: 2,
                ),
                onChanged: ratioChanged,
                validator: ratioError,
              ),
              const SizedBox(height: 10),
              Text(
                'Вода и вливания пересчитаются до целых граммов. Время останется прежним.',
                style: TextStyle(
                  fontSize: 11,
                  color: context.colors.muted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              f.field(
                'temperature',
                'Температура',
                numeric: true,
                required: true,
                min: 50,
                max: 100,
                suffix: '°C',
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: f.field('grind', 'Помол', required: true)),
                  const SizedBox(width: 12),
                  Expanded(child: f.field('unit', 'Единицы', required: true)),
                ],
              ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text(
                  'Оборудование и вода',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  f.text('grinder'),
                  style: TextStyle(fontSize: 12, color: context.colors.muted),
                ),
                childrenPadding: const EdgeInsets.only(top: 14),
                children: [
                  f.field('grinder', 'Кофемолка', required: true),
                  f.field('dripper', 'Воронка и размер', required: true),
                  f.field('filter', 'Фильтр', required: true),
                  f.field('brewWater', 'Вода · необязательно'),
                ],
              ),
              const SectionLabel('План вливаний'),
              Text(
                'Суммарный вес воды на весах',
                style: TextStyle(fontSize: 12, color: context.colors.muted),
              ),
              const SizedBox(height: 20),
              for (var i = 0; i < steps.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 28,
                        height: 56,
                        child: Center(
                          child: Text(
                            '${i + 1}'.padLeft(2, '0'),
                            style: mono(12, context.colors.terra),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DurationField(
                          controller: steps[i].time,
                          label: 'Начало',
                          minSeconds: 0,
                          maxSeconds: 3599,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: steps[i].water,
                          onChanged: (value) {
                            final n = double.tryParse(
                              value.replaceAll(',', '.'),
                            );
                            if (n != null && n.isFinite && n > 0) {
                              fractions[i] = n / previousWater;
                            }
                          },
                          style: mono(15),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Влить до',
                            suffixText: 'г',
                          ),
                          validator: (v) {
                            final n = double.tryParse(
                              (v ?? '').replaceAll(',', '.'),
                            );
                            return n == null ||
                                    !n.isFinite ||
                                    n <= 0 ||
                                    n != n.roundToDouble()
                                ? 'Целое число > 0'
                                : null;
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              if (stepError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    stepError!,
                    style: TextStyle(color: context.colors.terra, fontSize: 12),
                  ),
                ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: steps.length >= 8
                        ? null
                        : () => setState(() {
                            final lastTime =
                                parseTime(steps.last.time.text) ?? 0;
                            steps.add(
                              StepFields({
                                'time': lastTime + 30,
                                'water':
                                    double.tryParse(f.text('water')) ?? 250,
                              }),
                            );
                            fractions.add(1);
                          }),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Добавить этап'),
                  ),
                  const Spacer(),
                  if (steps.length > 1)
                    IconButton(
                      tooltip: 'Удалить последний этап',
                      onPressed: () => setState(() {
                        final removed = steps.removeLast();
                        fractions.removeLast();
                        Future.delayed(
                          const Duration(seconds: 1),
                          removed.dispose,
                        );
                      }),
                      icon: const Icon(Icons.remove, size: 20),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              DurationField(
                controller: f.c('duration'),
                label: 'Ориентировочное время',
                minSeconds: 30,
                maxSeconds: 3600,
                helperText: 'Затем дождитесь завершения пролива.',
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: busy ? null : saveRecipe,
                icon: const Icon(Icons.bookmark_border, size: 18),
                label: const Text('Сохранить рецепт'),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
          decoration: BoxDecoration(
            color: context.colors.bg,
            border: Border(top: BorderSide(color: context.colors.line)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Primary(
                busy ? 'Подготовка…' : 'Начать заваривание',
                icon: Icons.play_arrow_outlined,
                onPressed: busy ? null : () => start(false),
              ),
              TextButton(
                onPressed: busy ? null : () => start(true),
                child: const Text('Записать без таймера'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
