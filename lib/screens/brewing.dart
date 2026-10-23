part of '../app.dart';

class TimerPage extends StatefulWidget {
  final BloomStore store;
  const TimerPage({super.key, required this.store});
  @override
  State<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> with WidgetsBindingObserver {
  late Json session;
  late final Timer ticker;
  late final DateTime started;
  int elapsed = 0, previousStep = 0;
  bool busy = false, canLeave = false;
  bool foreground = true;
  AudioPlayer? player;
  Json get recipe => session['recipe'];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    session = clone(widget.store.session!);
    started = DateTime.parse(session['started']);
    elapsed = math.max(0, DateTime.now().difference(started).inSeconds);
    previousStep = currentStep(recipe, elapsed);
    ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (foreground) refreshElapsed();
    });
  }

  void refreshElapsed({bool playCue = true}) {
    final seconds = math.max(0, DateTime.now().difference(started).inSeconds);
    if (seconds == elapsed || !mounted) return;
    final step = currentStep(recipe, seconds);
    if (playCue && step != previousStep && session['sound'] == true) _cue();
    previousStep = step;
    setState(() => elapsed = seconds);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (foreground) {
      // iOS suspends timers in the background. Restore wall-clock time without
      // announcing a pouring instruction whose scheduled time has passed.
      refreshElapsed(playCue: false);
    }
  }

  Future<void> _cue() async {
    try {
      player ??= AudioPlayer();
      await player!.play(AssetSource('audio/step.wav'));
      await HapticFeedback.selectionClick();
    } catch (_) {
      if (mounted) {
        toast(context, 'Звук недоступен. Следите за этапами на экране.');
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ticker.cancel();
    player?.dispose();
    super.dispose();
  }

  Future<void> leave() async {
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Заваривание идёт'),
        content: const Text(
          'Можно свернуть таймер — он продолжит отсчёт. При отмене зерно не списывается.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Отменить заваривание'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'minimize'),
            child: const Text('Свернуть'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Продолжить'),
          ),
        ],
      ),
    );
    if (action == null || !mounted) return;
    if (action == 'cancel') await widget.store.cancelSession();
    if (!mounted) return;
    setState(() => canLeave = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> finish() async {
    if (busy) return;
    setState(() => busy = true);
    await guard(context, () async {
      session['state'] = 'result';
      session['elapsed'] = elapsed;
      await widget.store.updateSession(session);
      if (!mounted) return;
      setState(() => canLeave = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => ResultPage(store: widget.store),
            ),
          );
        }
      });
    });
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final steps = recipe['steps'] as List, index = currentStep(recipe, elapsed);
    final next = index + 1 < steps.length ? steps[index + 1] : null;
    final over = elapsed >= recipe['duration'];
    final pack = widget.store.pack(recipe['packId']);
    return PopScope(
      canPop: canLeave,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) leave();
      },
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          leading: IconButton(
            onPressed: leave,
            tooltip: 'Выйти из таймера',
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          ),
          title: const Text('Заваривание'),
          actions: [
            IconButton(
              tooltip: session['sound'] == true
                  ? 'Выключить подсказки'
                  : 'Включить подсказки',
              onPressed: () async {
                setState(() => session['sound'] = session['sound'] != true);
                if (session['sound'] == true) _cue();
                await widget.store.updateSession(session);
              },
              icon: Icon(
                session['sound'] == true
                    ? Icons.volume_up_outlined
                    : Icons.volume_off_outlined,
              ),
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: SafeArea(
          top: false,
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final diameter = math.min(
                constraints.maxWidth - 64,
                (constraints.maxHeight * .37).clamp(224.0, 284.0),
              );
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 40,
                          child: CoffeeCover(pack, height: 52),
                        ),
                        const SizedBox(width: 14),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                recipe['name'],
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                pack['name'],
                                style: TextStyle(
                                  fontSize: 13,
                                  color: context.colors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    BrewTimerDial(
                      elapsed: elapsed,
                      duration: recipe['duration'],
                      step: index + 1,
                      stepCount: steps.length,
                      diameter: diameter,
                    ),
                    const SizedBox(height: 22),
                    Text(
                      over
                          ? 'Чашка почти готова'
                          : 'Влейте до ${amount(steps[index]['water'])} г',
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      over
                          ? 'Нажмите «Завершить», когда вода пройдёт через кофе.'
                          : 'Суммарный вес воды на весах',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.muted,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Surface(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  next != null
                                      ? 'Далее · ${clock(next['time'])}'
                                      : 'Ориентир · ${clock(recipe['duration'])}',
                                  style: mono(12, context.colors.muted),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  next != null
                                      ? 'Влить до ${amount(next['water'])} г'
                                      : 'Дождитесь завершения пролива',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.schedule_outlined,
                            color: context.colors.muted,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Surface(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: IntrinsicHeight(
                        child: Row(
                          children: [
                            _TimerMetric('${amount(recipe['dose'])} г', 'кофе'),
                            VerticalDivider(
                              width: 1,
                              color: context.colors.line,
                            ),
                            _TimerMetric(
                              '${amount(recipe['water'])} г',
                              'воды',
                            ),
                            VerticalDivider(
                              width: 1,
                              color: context.colors.line,
                            ),
                            _TimerMetric(
                              '${amount(recipe['temperature'])} °C',
                              'температура',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${recipe['grinder']} · ${recipe['grind']} ${recipe['unit']}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.muted,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Primary(
              busy ? 'Завершаем…' : 'Завершить',
              onPressed: busy ? null : finish,
            ),
          ),
        ),
      ),
    );
  }
}

class _TimerMetric extends StatelessWidget {
  final String value, label;
  const _TimerMetric(this.value, this.label);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: mono(16)),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: context.colors.muted),
          ),
        ],
      ),
    ),
  );
}

/// The ring represents the recipe's planned duration, never measured water.
class BrewTimerDial extends StatelessWidget {
  final int elapsed, duration, step, stepCount;
  final double diameter;

  const BrewTimerDial({
    super.key,
    required this.elapsed,
    required this.duration,
    required this.step,
    required this.stepCount,
    this.diameter = 280,
  });

  @override
  Widget build(BuildContext context) {
    final time = clock(elapsed).padLeft(5, '0');
    final stage = 'Этап $step из $stepCount';
    return Semantics(
      label: 'Прошло $time. $stage. Ориентир ${clock(duration)}',
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: diameter,
          child: CustomPaint(
            painter: _TimerRingPainter(
              duration > 0 ? (elapsed / duration).clamp(0.0, 1.0) : 1,
              trackColor: context.colors.track,
              activeColor: context.colors.accent,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(time, style: timerDigits(diameter * .235)),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.track,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      stage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
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
}

class _TimerRingPainter extends CustomPainter {
  final double progress;
  final Color trackColor, activeColor;
  const _TimerRingPainter(
    this.progress, {
    required this.trackColor,
    required this.activeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.shortestSide * .04;
    final bounds = (Offset.zero & size).deflate(strokeWidth / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt
      ..color = trackColor;
    canvas.drawOval(bounds, paint);
    if (progress > 0) {
      canvas.drawArc(
        bounds,
        -math.pi / 2,
        math.pi * 2 * progress,
        false,
        paint..color = activeColor,
      );
    }
  }

  @override
  bool shouldRepaint(_TimerRingPainter oldDelegate) =>
      progress != oldDelegate.progress ||
      trackColor != oldDelegate.trackColor ||
      activeColor != oldDelegate.activeColor;
}

class ResultPage extends StatefulWidget {
  final BloomStore store;
  const ResultPage({super.key, required this.store});
  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> with WidgetsBindingObserver {
  final f = FormFields();
  final form = GlobalKey<FormState>();
  late final Json session, planned;
  String? rating;
  bool repeat = false, busy = false, canLeave = false;
  Json taste = {
    'Кислотность': 3.0,
    'Сладость': 3.0,
    'Горечь': 3.0,
    'Тело': 3.0,
  };
  bool tasteChanged = false;
  Timer? debounce;
  Future<bool> draftWrite = Future<bool>.value(true);
  bool draftClosed = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    session = clone(widget.store.session!);
    planned = clone(session['recipe']);
    final saved = session['draft'] as Json?;
    for (final key in ['dose', 'water', 'temperature']) {
      f.c(key, saved?[key] ?? amount(planned[key]));
    }
    f.c('grind', saved?['grind'] ?? planned['grind']);
    f.c('duration', saved?['duration'] ?? clock(session['elapsed']));
    f.c('note', saved?['note'] ?? '');
    f.c('next', saved?['next'] ?? '');
    rating = saved?['rating'];
    repeat = saved?['repeat'] ?? false;
    // Older drafts may not contain newly added optional taste dimensions.
    taste = {...taste, ...?(saved?['taste'] as Json?)};
    tasteChanged = saved?['tasteChanged'] ?? false;
    for (final controller in f.controllers.values) {
      controller.addListener(queueDraft);
    }
  }

  void queueDraft() {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 400), persistDraft);
  }

  Future<void> persistDraft() async {
    await flushDraft();
  }

  Future<bool> flushDraft() {
    if (!mounted ||
        busy ||
        draftClosed ||
        widget.store.session?['id'] != session['id']) {
      return draftWrite;
    }
    final snapshot = clone(session)
      ..['draft'] = {
        for (final key in f.controllers.keys) key: f.text(key),
        'rating': rating,
        'repeat': repeat,
        'taste': clone(taste),
        'tasteChanged': tasteChanged,
      };
    session['draft'] = snapshot['draft'];
    // Serialize debounce and lifecycle writes so an older snapshot cannot
    // overwrite the latest edit or finish after the session is deleted.
    draftWrite = draftWrite
        .then((_) async {
          if (!mounted ||
              busy ||
              draftClosed ||
              widget.store.session?['id'] != session['id']) {
            return false;
          }
          await widget.store.updateSession(snapshot);
          return true;
        })
        .catchError((Object error, StackTrace stack) {
          debugPrint('Bloom draft persistence: $error\n$stack');
          if (mounted &&
              WidgetsBinding.instance.lifecycleState ==
                  AppLifecycleState.resumed) {
            toast(
              context,
              'Не удалось сохранить черновик. Не закрывайте приложение и попробуйте ещё раз.',
            );
          }
          return false;
        });
    return draftWrite;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      // Flush before iOS can suspend the isolate; do not wait for debounce.
      debounce?.cancel();
      unawaited(persistDraft());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    draftClosed = true;
    debounce?.cancel();
    f.dispose();
    super.dispose();
  }

  Future<void> leave() async {
    await persistDraft();
    if (!mounted) return;
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Сохранить чашку позже?'),
        content: const Text(
          'Черновик останется на главном экране. Остаток изменится только после сохранения.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Продолжить'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить черновик'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Сохранить позже'),
          ),
        ],
      ),
    );
    if (discard == null || !mounted) return;
    debounce?.cancel();
    if (discard) {
      draftClosed = true;
      await draftWrite;
      await widget.store.cancelSession();
    } else {
      if (!await flushDraft()) return;
      draftClosed = true;
    }
    if (!mounted) return;
    setState(() => canLeave = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    if (rating == null) {
      toast(context, 'Оцените чашку перед сохранением');
      return;
    }
    final actual = clone(planned);
    for (final key in ['dose', 'water', 'temperature']) {
      actual[key] = f.n(key);
    }
    actual['grind'] = f.text('grind');
    actual['duration'] = parseTime(f.text('duration'))!;
    actual['steps'] = scaleSteps(
      planned['steps'],
      number(planned['water']),
      number(actual['water']),
    );
    debounce?.cancel();
    final draftSaved = await flushDraft();
    if (!mounted) return;
    setState(() => busy = true);
    try {
      if (!await checkStock(context, widget.store, actual)) return;
      final brew = <String, dynamic>{
        'id': session['id'],
        'packId': actual['packId'],
        'recipe': actual,
        'plannedRecipe': planned,
        'elapsed': parseTime(f.text('duration')),
        'date': DateTime.now().toIso8601String(),
        'rating': rating,
        'repeat': repeat,
        'favorite': false,
        'note': f.text('note'),
        'next': f.text('next'),
        'taste': tasteChanged ? taste : <String, dynamic>{},
      };
      await widget.store.saveBrew(brew);
      draftClosed = true;
      if (!mounted) return;
      setState(() => canLeave = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(
            builder: (_) => SavedPage(store: widget.store, brewId: brew['id']),
          ),
          (route) => route.isFirst,
        );
      });
    } on InsufficientCoffee catch (e) {
      if (mounted) {
        toast(
          context,
          'Осталось ${amount(e.remaining)} г. Проверьте массу пачки.',
        );
      }
    } catch (e) {
      if (mounted) {
        toast(
          context,
          draftSaved
              ? 'Не удалось сохранить чашку. Черновик сохранён, попробуйте ещё раз.'
              : 'Не удалось сохранить чашку и черновик. Не закрывайте приложение и попробуйте ещё раз.',
        );
      }
      debugPrint('$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: canLeave,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && !busy) leave();
    },
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Ваша чашка'),
        leading: IconButton(
          onPressed: busy ? null : leave,
          tooltip: 'Назад',
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Form(
        key: form,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.coffee_outlined,
                size: 38,
                color: context.colors.terra,
              ),
              const SizedBox(height: 16),
              Text(
                'Как получилось?',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                widget.store.pack(planned['packId'])['name'],
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.muted, fontSize: 13),
              ),
              const SizedBox(height: 28),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < ratings.length; i++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: i == 2 ? 0 : 8),
                        child: Semantics(
                          selected: rating == ratings[i],
                          child: InkWell(
                            onTap: () {
                              setState(() => rating = ratings[i]);
                              queueDraft();
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 100),
                              decoration: BoxDecoration(
                                color: rating == ratings[i]
                                    ? context.colors.accent
                                    : context.colors.surface,
                                border: Border.all(
                                  color: rating == ratings[i]
                                      ? context.colors.accent
                                      : context.colors.line,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 14,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    [
                                      Icons.sentiment_satisfied_alt_outlined,
                                      Icons.sentiment_neutral_outlined,
                                      Icons.sentiment_dissatisfied_outlined,
                                    ][i],
                                    color: rating == ratings[i]
                                        ? context.colors.onAccent
                                        : context.colors.ink,
                                    size: 26,
                                  ),
                                  const SizedBox(height: 9),
                                  Text(
                                    ratings[i],
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: rating == ratings[i]
                                          ? context.colors.onAccent
                                          : context.colors.ink,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Хочу повторить',
                  style: TextStyle(fontSize: 14),
                ),
                subtitle: Text(
                  'Сохранить намерение в журнале',
                  style: TextStyle(fontSize: 11, color: context.colors.muted),
                ),
                value: repeat,
                onChanged: (v) {
                  setState(() => repeat = v!);
                  queueDraft();
                },
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SectionLabel('Фактические параметры'),
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  'Уточните, если что-то изменилось в процессе.',
                  style: TextStyle(color: context.colors.muted, fontSize: 12),
                ),
              ),
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
                      integer: true,
                      suffix: 'г',
                    ),
                  ),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: f.field(
                      'temperature',
                      'Температура',
                      numeric: true,
                      required: true,
                      min: 50,
                      max: 100,
                      suffix: '°C',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: f.field(
                      'grind',
                      'Помол',
                      required: true,
                      suffix: planned['unit'],
                    ),
                  ),
                ],
              ),
              DurationField(
                controller: f.c('duration'),
                label: 'Фактическое время',
                fontSize: 18,
                minSeconds: 1,
                maxSeconds: 21600,
              ),
              const SectionLabel('Впечатления'),
              f.field('note', 'Заметка о вкусе', lines: 3),
              f.field('next', 'Что попробовать в следующий раз', lines: 2),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text(
                  'Подробнее о вкусе',
                  style: TextStyle(fontSize: 14),
                ),
                subtitle: Text(
                  'Необязательно',
                  style: TextStyle(fontSize: 11, color: context.colors.muted),
                ),
                children: [
                  for (final key in taste.keys)
                    Column(
                      children: [
                        Row(
                          children: [
                            Text(key, style: const TextStyle(fontSize: 13)),
                            const Spacer(),
                            Text(
                              '${number(taste[key]).round()} / 5',
                              style: mono(12),
                            ),
                          ],
                        ),
                        Slider(
                          key: ValueKey('taste-$key'),
                          value: number(taste[key]),
                          min: 1,
                          max: 5,
                          divisions: 4,
                          label: '${number(taste[key]).round()}',
                          semanticFormatterCallback: (value) =>
                              '$key: ${value.round()} из 5',
                          onChanged: (v) {
                            setState(() {
                              taste[key] = v;
                              tasteChanged = true;
                            });
                            queueDraft();
                          },
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          decoration: BoxDecoration(
            color: context.colors.bg,
            border: Border(top: BorderSide(color: context.colors.line)),
          ),
          child: Primary(
            busy ? 'Сохраняем…' : 'Сохранить заваривание',
            icon: Icons.check,
            onPressed: busy ? null : save,
          ),
        ),
      ),
    ),
  );
}

class SavedPage extends StatelessWidget {
  final BloomStore store;
  final String brewId;
  const SavedPage({super.key, required this.store, required this.brewId});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final brew = store.brews.firstWhere((b) => b['id'] == brewId);
      return Scaffold(
        appBar: AppBar(title: const Text('Чашка в журнале')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 36),
              const Icon(Icons.check_circle_outline, size: 64),
              const SizedBox(height: 24),
              Text(
                'Хороший момент\nсохранён.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 16),
              Text(
                'Остаток пачки — ${amount(store.pack(brew['packId'])['remaining'])} г.\nТеперь эту чашку легко повторить.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.colors.muted,
                  fontSize: 14,
                  height: 1.7,
                ),
              ),
              const SizedBox(height: 32),
              Primary(
                brew['favorite'] == true
                    ? 'Любимая чашка'
                    : 'Отметить как любимую',
                icon: brew['favorite'] == true
                    ? Icons.favorite
                    : Icons.favorite_border,
                onPressed: () =>
                    guard(context, () => store.toggleFavorite(brew)),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => saveAsRecipe(context, store, brew),
                icon: const Icon(Icons.bookmark_border, size: 18),
                label: const Text('Сохранить отдельным рецептом'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () =>
                    push(context, BrewDetail(store: store, brewId: brewId)),
                child: const Text('Посмотреть запись'),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () =>
                    Navigator.popUntil(context, (route) => route.isFirst),
                child: const Text('К моему кофе'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> saveAsRecipe(
  BuildContext context,
  BloomStore store,
  Json brew,
) async {
  final name = await editText(
    context,
    title: 'Название нового рецепта',
    initial: '${brew['recipe']['name']} · удачная чашка',
  );
  if (name == null || !context.mounted) return;
  if (name.isEmpty) {
    toast(context, 'Укажите название рецепта');
    return;
  }
  final recipe = clone(brew['recipe'])
    ..['id'] = uid()
    ..['name'] = name;
  // The actual time can be shorter than the last planned pour. Keep a usable plan.
  final lastTime = (recipe['steps'] as List).last['time'] as int;
  if (recipe['duration'] <= lastTime) recipe['duration'] = lastTime + 30;
  await guard(context, () async {
    await store.saveRecipe(recipe);
    if (context.mounted) toast(context, 'Новый рецепт сохранён');
  });
}
