part of '../app.dart';

class CoffeeList extends StatefulWidget {
  final BloomStore store;
  const CoffeeList({super.key, required this.store});
  @override
  State<CoffeeList> createState() => _CoffeeListState();
}

class _CoffeeListState extends State<CoffeeList> {
  bool archive = false;
  @override
  Widget build(BuildContext context) {
    final packs = widget.store.packs
        .where((p) => p['archived'] == archive)
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      children: [
        Row(
          children: [
            Transform.translate(
              // Align the visible mark, including its transparent padding, to B.
              offset: const Offset(0, -0.65),
              child: Image.asset(
                'assets/brand/bloom-mark.png',
                width: 42,
                height: 42,
                cacheWidth: 168,
                color: context.colors.accent,
                colorBlendMode: BlendMode.srcIn,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                heightFactor: 1,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Bloom',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 42,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.2,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            IconButton.filled(
              onPressed: () => push(context, PackEditor(store: widget.store)),
              tooltip: 'Добавить пачку',
              style: IconButton.styleFrom(
                minimumSize: const Size(44, 44),
                backgroundColor: context.colors.accent,
                foregroundColor: context.colors.onAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: context.colors.track,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              for (final (value, label) in [
                (false, 'Активные'),
                (true, 'Архив'),
              ])
                Expanded(
                  child: Semantics(
                    selected: archive == value,
                    child: TextButton(
                      onPressed: () => setState(() => archive = value),
                      style: TextButton.styleFrom(
                        backgroundColor: archive == value
                            ? (context.colors.isDark
                                  ? context.colors.accent
                                  : context.colors.surface)
                            : Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: archive == value
                              ? (context.colors.isDark
                                    ? context.colors.onAccent
                                    : context.colors.ink)
                              : context.colors.muted,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Text(
              archive ? 'СОХРАНЁННЫЕ ПАЧКИ' : 'НА ВАШЕЙ ПОЛКЕ',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.5,
                color: context.colors.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text('${packs.length}', style: mono(12, context.colors.muted)),
          ],
        ),
        const SizedBox(height: 12),
        if (packs.isEmpty)
          EmptyState(
            title: archive ? 'Архив пока пуст' : 'Добавьте первую пачку',
            subtitle: archive
                ? 'Здесь останутся закончившиеся пачки\nвместе с рецептами и историей.'
                : 'Сохраните зерно — и найдите\nсвой любимый рецепт.',
            action: archive ? 'К активным пачкам' : 'Добавить пачку',
            onPressed: () {
              if (archive) {
                setState(() => archive = false);
              } else {
                push(context, PackEditor(store: widget.store));
              }
            },
          ),
        for (final p in packs)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: PackCard(pack: p, store: widget.store),
          ),
      ],
    );
  }
}

class PackCard extends StatelessWidget {
  final Json pack;
  final BloomStore store;
  const PackCard({super.key, required this.pack, required this.store});
  @override
  Widget build(BuildContext context) => Material(
    color: context.colors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: context.colors.line),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => push(context, PackDetail(store: store, packId: pack['id'])),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                CoffeeCover(pack, height: 145),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'ДЛЯ ФИЛЬТРА',
                      style: TextStyle(fontSize: 8, letterSpacing: 1.2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(pack['name'], style: Theme.of(context).textTheme.titleLarge),
            if ((pack['roaster'] ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  pack['roaster'],
                  style: TextStyle(fontSize: 12, color: context.colors.muted),
                ),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if ((pack['process'] ?? '').isNotEmpty)
                  Text(
                    pack['process'],
                    style: TextStyle(fontSize: 11, color: context.colors.muted),
                  ),
                if (pack['roastDate'] != null)
                  Text(
                    '·  Обжарка ${dateLabel(pack['roastDate'])}',
                    style: TextStyle(fontSize: 11, color: context.colors.muted),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Примерный остаток',
                    style: TextStyle(fontSize: 11, color: context.colors.muted),
                  ),
                ),
                const SizedBox(width: 8),
                Text('~ ${amount(pack['remaining'])} г', style: mono(12)),
              ],
            ),
            const SizedBox(height: 8),
            ExcludeSemantics(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: (number(pack['remaining']) / number(pack['mass']))
                      .clamp(0, 1),
                  minHeight: 3,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Primary(
              pack['archived'] == true ? 'Открыть пачку' : 'Заварить',
              icon: pack['archived'] == true
                  ? Icons.arrow_forward
                  : Icons.coffee_outlined,
              onPressed: () {
                if (pack['archived'] == true) {
                  push(context, PackDetail(store: store, packId: pack['id']));
                  return;
                }
                final last = store.last(pack['id']);
                final recipe =
                    last?['recipe'] as Json? ??
                    store.packRecipes(pack['id']).firstOrNull;
                openRecipe(
                  context,
                  store,
                  pack['id'],
                  recipe: recipe,
                  fromBrew: last != null,
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class PackEditor extends StatefulWidget {
  final BloomStore store;
  final Json? pack;
  const PackEditor({super.key, required this.store, this.pack});
  @override
  State<PackEditor> createState() => _PackEditorState();
}

class _PackEditorState extends State<PackEditor> {
  final fields = FormFields();
  final form = GlobalKey<FormState>();
  String? roast, opened, photo;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    final p = widget.pack;
    for (final key in ['name', 'roaster', 'country', 'process', 'notes']) {
      fields.c(key, p?[key] ?? '');
    }
    fields.c('mass', p == null ? '250' : amount(p['mass']));
    roast = p?['roastDate'];
    opened = p?['openDate'];
    photo = p?['photo'];
  }

  @override
  void dispose() {
    fields.dispose();
    super.dispose();
  }

  Future<void> pickPhoto() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
        // The cover only needs pixels, not EXIF metadata or full-library access.
        requestFullMetadata: false,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        if (bytes.length > 1000000) {
          if (mounted) {
            toast(
              context,
              'Фото слишком большое. Выберите изображение до 1 МБ.',
            );
          }
          return;
        }
        if (mounted) setState(() => photo = base64Encode(bytes));
      }
    } catch (_) {
      if (mounted) {
        toast(
          context,
          'Не удалось открыть фото. Попробуйте другое изображение.',
        );
      }
    }
  }

  Future<void> pickDate(bool isRoast) async {
    final current = isRoast ? roast : opened;
    final date = await showDatePicker(
      context: context,
      initialDate: current == null ? DateTime.now() : DateTime.parse(current),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: isRoast ? 'Дата обжарки' : 'Дата открытия',
    );
    if (date != null) {
      setState(() {
        if (isRoast) {
          roast = date.toIso8601String();
        } else {
          opened = date.toIso8601String();
        }
      });
    }
  }

  Widget dateField(bool isRoast) {
    final value = isRoast ? roast : opened;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => pickDate(isRoast),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: isRoast
                ? 'Дата обжарки · необязательно'
                : 'Дата открытия · необязательно',
            suffixIcon: value == null
                ? const Icon(Icons.calendar_today_outlined, size: 18)
                : IconButton(
                    tooltip: 'Убрать дату',
                    onPressed: () => setState(() {
                      if (isRoast) {
                        roast = null;
                      } else {
                        opened = null;
                      }
                    }),
                    icon: const Icon(Icons.close, size: 18),
                  ),
          ),
          child: Text(
            value == null ? 'Выбрать дату' : dateLabel(value),
            style: TextStyle(
              fontSize: 14,
              color: value == null ? context.colors.muted : context.colors.ink,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> save() async {
    if (!form.currentState!.validate() || busy) return;
    if (roast != null &&
        opened != null &&
        DateTime.parse(opened!).isBefore(DateTime.parse(roast!))) {
      toast(context, 'Дата открытия не может быть раньше обжарки');
      return;
    }
    setState(() => busy = true);
    await guard(context, () async {
      final p = widget.pack == null
          ? <String, dynamic>{
              'id': uid(),
              'archived': false,
              'remaining': fields.n('mass'),
              'cover': 0,
              'next': '',
            }
          : clone(widget.pack!);
      for (final key in ['name', 'roaster', 'country', 'process', 'notes']) {
        p[key] = fields.text(key);
      }
      p.addAll({
        'mass': fields.n('mass'),
        'roastDate': roast,
        'openDate': opened,
        'photo': photo,
      });
      await widget.store.savePack(p);
      if (mounted) {
        toast(context, 'Пачка сохранена');
        Navigator.pop(context);
      }
    });
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.pack == null ? 'Новая пачка' : 'Редактировать пачку'),
    ),
    body: Form(
      key: form,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          24, 12, 24, 32 + MediaQuery.paddingOf(context).bottom,
        ),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          Text(
            'Начнём с зерна',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 24),
          InkWell(
            onTap: pickPhoto,
            borderRadius: BorderRadius.circular(16),
            child: photo == null
                ? Surface(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 30,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Добавить фото'),
                              const SizedBox(height: 3),
                              Text(
                                'Необязательно',
                                style: TextStyle(
                                  color: context.colors.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.add),
                      ],
                    ),
                  )
                : CoffeeCover({'photo': photo}, height: 150),
          ),
          if (photo != null)
            TextButton(
              onPressed: () => setState(() => photo = null),
              child: const Text('Убрать фото'),
            ),
          const SizedBox(height: 24),
          fields.field('name', 'Название зерна', required: true),
          fields.field('roaster', 'Обжарщик · необязательно'),
          fields.field(
            'mass',
            'Масса пачки',
            required: true,
            numeric: true,
            min: 1,
            suffix: 'г',
          ),
          dateField(true),
          dateField(false),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text(
              'Страна, обработка и заметки',
              style: TextStyle(fontSize: 14),
            ),
            childrenPadding: const EdgeInsets.only(top: 12),
            children: [
              fields.field('country', 'Страна'),
              fields.field('process', 'Обработка'),
              fields.field('notes', 'Заметки о зерне', lines: 3),
            ],
          ),
          const SizedBox(height: 24),
          Primary(
            busy ? 'Сохраняем…' : 'Сохранить пачку',
            onPressed: busy ? null : save,
          ),
        ],
      ),
    ),
  );
}

class PackDetail extends StatelessWidget {
  final BloomStore store;
  final String packId;
  const PackDetail({super.key, required this.store, required this.packId});
  Future<void> adjust(BuildContext context, Json p) async {
    final value = await editText(
      context,
      title: 'Фактический остаток, г',
      initial: amount(p['remaining']),
      numeric: true,
    );
    if (value != null && context.mounted) {
      await guard(
        context,
        () => store.savePack(
          clone(p)..['remaining'] = double.parse(value.replaceAll(',', '.')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final p = store.pack(packId),
          last = store.last(packId),
          favorite = store.favorite(packId);
      return Scaffold(
        appBar: AppBar(
          title: const Text('Мой кофе'),
          actions: [
            PopupMenuButton<String>(
              tooltip: 'Действия с пачкой',
              icon: const Icon(Icons.more_horiz),
              onSelected: (value) async {
                if (value == 'edit') {
                  push(context, PackEditor(store: store, pack: p));
                }
                if (value == 'mass') await adjust(context, p);
                if (value == 'archive' && context.mounted) {
                  await guard(
                    context,
                    () => store.savePack(
                      clone(p)..['archived'] = p['archived'] != true,
                    ),
                  );
                  if (context.mounted) {
                    toast(
                      context,
                      p['archived'] == true
                          ? 'Пачка снова активна'
                          : 'Пачка перенесена в архив',
                    );
                  }
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Text('Редактировать'),
                ),
                const PopupMenuItem(
                  value: 'mass',
                  child: Text('Уточнить остаток'),
                ),
                PopupMenuItem(
                  value: 'archive',
                  child: Text(
                    p['archived'] == true ? 'Вернуть в активные' : 'В архив',
                  ),
                ),
              ],
            ),
          ],
        ),
        body: ListView(
          padding: EdgeInsets.fromLTRB(
            24, 4, 24, 32 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            CoffeeCover(p, height: 200),
            const SizedBox(height: 24),
            if (p['archived'] == true)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'В АРХИВЕ',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.4,
                    color: context.colors.terra,
                  ),
                ),
              ),
            Text(p['name'], style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text(
              p['roaster'] ?? '',
              style: TextStyle(color: context.colors.muted),
            ),
            const SizedBox(height: 16),
            if ((p['notes'] ?? '').isNotEmpty)
              Text(
                p['notes'],
                style: TextStyle(
                  fontSize: 13,
                  color: context.colors.muted,
                  height: 1.5,
                ),
              ),
            const SizedBox(height: 18),
            Surface(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Metric(
                          '~ ${amount(p['remaining'])} г',
                          'из ${amount(p['mass'])} г',
                        ),
                      ),
                      Metric(
                        '${store.packBrews(packId).length}',
                        'заваривания',
                      ),
                      IconButton(
                        onPressed: () => adjust(context, p),
                        tooltip: 'Уточнить остаток',
                        icon: const Icon(Icons.edit_outlined, size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: (number(p['remaining']) / number(p['mass'])).clamp(
                      0,
                      1,
                    ),
                    minHeight: 3,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (last != null)
              Primary(
                'Повторить последнее',
                icon: Icons.replay,
                onPressed: () => openRecipe(
                  context,
                  store,
                  packId,
                  recipe: last['recipe'],
                  fromBrew: true,
                ),
              )
            else
              Primary(
                'Создать первый рецепт',
                icon: Icons.add,
                onPressed: () => openRecipe(context, store, packId),
              ),
            const SizedBox(height: 10),
            if (favorite != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => openRecipe(
                    context,
                    store,
                    packId,
                    recipe: favorite['recipe'],
                    fromBrew: true,
                  ),
                  icon: const Icon(Icons.favorite_border, size: 18),
                  label: const Text('Заварить любимое'),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Любимой чашки пока нет. Отметьте её сердцем в журнале.',
                  style: TextStyle(
                    color: context.colors.muted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
            SectionLabel(
              'Рецепты пачки',
              action: TextButton.icon(
                onPressed: () => openRecipe(context, store, packId),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Новый рецепт'),
              ),
            ),
            if (store.packRecipes(packId).isEmpty)
              Text(
                'Сохраните рецепт, чтобы повторить его завтра.',
                style: TextStyle(color: context.colors.muted, fontSize: 13),
              ),
            for (final r in store.packRecipes(packId))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: () => openRecipe(context, store, packId, recipe: r),
                  borderRadius: BorderRadius.circular(16),
                  child: Surface(
                    child: Row(
                      children: [
                        const Icon(Icons.filter_alt_outlined),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r['name'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '${amount(r['dose'])} г  /  ${amount(r['water'])} г  ·  ${clock(r['duration'])}',
                                style: mono(11, context.colors.muted),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            SectionLabel(
              'Что попробовать дальше',
              action: IconButton(
                tooltip: 'Изменить заметку',
                onPressed: () async {
                  final value = await editText(
                    context,
                    title: 'Следующий эксперимент',
                    initial: p['next'] ?? '',
                  );
                  if (value != null && context.mounted) {
                    await guard(
                      context,
                      () => store.savePack(clone(p)..['next'] = value),
                    );
                  }
                },
                icon: const Icon(Icons.edit_outlined, size: 18),
              ),
            ),
            Surface(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: context.colors.terra,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      (p['next'] ?? '').isEmpty
                          ? 'Оставьте идею для следующей чашки.'
                          : p['next'],
                      style: const TextStyle(fontSize: 13, height: 1.6),
                    ),
                  ),
                ],
              ),
            ),
            SectionLabel('История завариваний'),
            if (store.packBrews(packId).isEmpty)
              Text(
                'Здесь появится ваша первая чашка.',
                style: TextStyle(color: context.colors.muted, fontSize: 13),
              ),
            for (final b in store.packBrews(packId))
              BrewTile(store: store, brew: b),
            const SectionLabel('О зерне'),
            InfoRow(
              'Обработка',
              (p['process'] ?? '').isEmpty ? 'Не указана' : p['process'],
            ),
            InfoRow('Обжарка', dateLabel(p['roastDate'])),
            InfoRow('Открыта', dateLabel(p['openDate'])),
          ],
        ),
      );
    },
  );
}
