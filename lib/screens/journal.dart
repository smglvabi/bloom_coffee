part of '../app.dart';

class BrewTile extends StatelessWidget {
  final BloomStore store;
  final Json brew;
  final bool? selected;
  final VoidCallback? onSelect;
  const BrewTile({
    super.key,
    required this.store,
    required this.brew,
    this.selected,
    this.onSelect,
  });
  @override
  Widget build(BuildContext context) {
    final r = brew['recipe'] as Json;
    final parameterStyle = mono(13).copyWith(fontWeight: FontWeight.w600);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: context.colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected == true
                ? context.colors.accent
                : context.colors.line,
            width: selected == true ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap:
              onSelect ??
              () => push(context, BrewDetail(store: store, brewId: brew['id'])),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        dateLabel(brew['date']),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: context.colors.muted,
                        ),
                      ),
                    ),
                    if (selected != null)
                      Checkbox(
                        value: selected,
                        onChanged: (_) => onSelect?.call(),
                      )
                    else
                      IconButton(
                        tooltip: brew['favorite'] == true
                            ? 'Убрать из любимых'
                            : 'Отметить любимой',
                        onPressed: () =>
                            guard(context, () => store.toggleFavorite(brew)),
                        icon: Icon(
                          brew['favorite'] == true
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: brew['favorite'] == true
                              ? context.colors.accent
                              : context.colors.ink,
                          size: 20,
                        ),
                      ),
                  ],
                ),
                Text(
                  store.pack(brew['packId'])['name'],
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  r['name'],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: context.colors.muted,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Text(
                      '${amount(r['dose'])} / ${amount(r['water'])} г',
                      style: parameterStyle,
                    ),
                    Text('${r['grind']} ${r['unit']}', style: parameterStyle),
                    Text(clock(brew['elapsed']), style: parameterStyle),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      brew['rating'] == 'Понравилось'
                          ? Icons.sentiment_satisfied_alt_outlined
                          : brew['rating'] == 'Нормально'
                          ? Icons.sentiment_neutral_outlined
                          : Icons.sentiment_dissatisfied_outlined,
                      size: 17,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        brew['rating'],
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (brew['repeat'] == true)
                      Icon(Icons.replay, size: 16, color: context.colors.muted),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class Journal extends StatefulWidget {
  final BloomStore store;
  const Journal({super.key, required this.store});
  @override
  State<Journal> createState() => _JournalState();
}

class _JournalPackField extends StatelessWidget {
  final String name;
  final VoidCallback onTap;
  const _JournalPackField({required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    key: const ValueKey('journal-pack-picker'),
    color: context.colors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: context.colors.line),
    ),
    clipBehavior: Clip.antiAlias,
    child: Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                Icons.coffee_outlined,
                size: 22,
                color: context.colors.muted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Пачка',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: context.colors.muted,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                        color: context.colors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.keyboard_arrow_down,
                size: 22,
                color: context.colors.muted,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _JournalPackSheet extends StatelessWidget {
  final List<Json> packs;
  final String? selectedId;
  const _JournalPackSheet({required this.packs, required this.selectedId});

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: context.colors.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Выбор пачки',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: context.colors.ink,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Закрыть выбор пачки',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 22),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: packs.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final pack = index == 0 ? null : packs[index - 1];
                final id = pack?['id'] as String?;
                final selected = selectedId == id;
                final roaster = (pack?['roaster'] as String? ?? '').trim();
                return Material(
                  key: ValueKey('journal-pack-option-${id ?? 'all'}'),
                  color: selected
                      ? context.colors.track
                      : context.colors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: context.colors.line),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Semantics(
                    button: true,
                    selected: selected,
                    child: InkWell(
                      onTap: () => Navigator.pop(context, id ?? ''),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            ExcludeSemantics(
                              child: SizedBox(
                                width: 48,
                                height: 56,
                                child: pack == null
                                    ? Icon(
                                        Icons.inventory_2_outlined,
                                        size: 26,
                                        color: context.colors.muted,
                                      )
                                    : CoffeeCover(pack, height: 56),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pack?['name'] ?? 'Все пачки',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      height: 1.35,
                                      color: context.colors.ink,
                                    ),
                                  ),
                                  if (roaster.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      roaster,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        height: 1.4,
                                        color: selected
                                            ? context.colors.ink
                                            : context.colors.muted,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 22,
                              child: selected
                                  ? Icon(
                                      Icons.check,
                                      size: 22,
                                      color: context.colors.accent,
                                    )
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class _JournalState extends State<Journal> {
  String? packId, rating;
  bool comparing = false;
  final Set<String> selected = {};

  Future<void> pickPack() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      backgroundColor: context.colors.bg,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (_) =>
          _JournalPackSheet(packs: widget.store.packs, selectedId: packId),
    );
    if (choice == null || !mounted) return;
    setState(() {
      packId = choice.isEmpty ? null : choice;
      selected.clear();
    });
  }

  void select(Json brew) {
    if (selected.contains(brew['id'])) {
      setState(() => selected.remove(brew['id']));
      return;
    }
    if (selected.length == 2) {
      toast(context, 'Для сравнения выберите ровно две чашки');
      return;
    }
    if (selected.isNotEmpty &&
        widget.store.brews.firstWhere(
              (b) => b['id'] == selected.first,
            )['packId'] !=
            brew['packId']) {
      toast(context, 'Выберите две попытки одной пачки');
      return;
    }
    setState(() => selected.add(brew['id']));
  }

  @override
  Widget build(BuildContext context) {
    final selectedPack = widget.store.packs
        .where((pack) => pack['id'] == packId)
        .firstOrNull;
    final brews = widget.store.brews
        .where(
          (b) =>
              (packId == null || b['packId'] == packId) &&
              (rating == null || b['rating'] == rating),
        )
        .toList();
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Журнал',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: comparing
                        ? 'Отменить выбор'
                        : 'Выбрать для сравнения',
                    onPressed: () => setState(() {
                      comparing = !comparing;
                      selected.clear();
                    }),
                    icon: Icon(comparing ? Icons.close : Icons.compare_arrows),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _JournalPackField(
                name: selectedPack?['name'] ?? 'Все пачки',
                onTap: pickPack,
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final value in [null, ...ratings])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(value ?? 'Все оценки'),
                          labelStyle: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: rating == value
                                ? context.colors.onSelected
                                : context.colors.ink,
                          ),
                          selected: rating == value,
                          onSelected: (_) => setState(() {
                            rating = value;
                            selected.clear();
                          }),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (comparing)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Выберите две чашки одной пачки',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${brews.length} заваривания',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: context.colors.muted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        textStyle: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () => setState(() {
                        comparing = true;
                        selected.clear();
                      }),
                      icon: const Icon(Icons.compare_arrows, size: 18),
                      label: const Text('Сравнить'),
                    ),
                  ],
                ),
              if (brews.isEmpty)
                EmptyState(
                  title: 'Здесь будут ваши чашки',
                  subtitle: packId != null || rating != null
                      ? 'По выбранным фильтрам ничего не найдено.'
                      : 'Заварите кофе и сохраните впечатления.',
                  action: 'Сбросить фильтры',
                  onPressed: () => setState(() {
                    packId = null;
                    rating = null;
                    selected.clear();
                  }),
                ),
              for (final b in brews)
                BrewTile(
                  store: widget.store,
                  brew: b,
                  selected: comparing ? selected.contains(b['id']) : null,
                  onSelect: comparing ? () => select(b) : null,
                ),
            ],
          ),
        ),
        if (comparing)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
            child: Primary(
              'Сравнить · ${selected.length} из 2',
              onPressed: selected.length == 2
                  ? () => push(
                      context,
                      ComparePage(
                        store: widget.store,
                        brewIds: selected.toList(),
                      ),
                    )
                  : null,
            ),
          ),
      ],
    );
  }
}

class BrewDetail extends StatelessWidget {
  final BloomStore store;
  final String brewId;
  const BrewDetail({super.key, required this.store, required this.brewId});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final b = store.brews.firstWhere((b) => b['id'] == brewId),
          r = b['recipe'] as Json;
      final previous = store
          .packBrews(b['packId'])
          .where((other) => other['id'] != brewId)
          .toList();
      return Scaffold(
        appBar: AppBar(
          title: const Text('Заваривание'),
          actions: [
            IconButton(
              tooltip: b['favorite'] == true
                  ? 'Убрать из любимых'
                  : 'Отметить любимой',
              onPressed: () => guard(context, () => store.toggleFavorite(b)),
              icon: Icon(
                b['favorite'] == true ? Icons.favorite : Icons.favorite_border,
                color: b['favorite'] == true
                    ? context.colors.accent
                    : context.colors.ink,
              ),
            ),
          ],
        ),
        body: ListView(
          padding: EdgeInsets.fromLTRB(
            24, 16, 24, 32 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            Text(
              dateLabel(b['date']),
              style: TextStyle(color: context.colors.muted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Text(
              store.pack(b['packId'])['name'],
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(r['name'], style: TextStyle(color: context.colors.muted)),
            const SizedBox(height: 24),
            Surface(
              child: Column(
                children: [
                  Wrap(
                    spacing: 24,
                    runSpacing: 16,
                    children: [
                      Metric('${amount(r['dose'])} г', 'кофе'),
                      Metric('${amount(r['water'])} г', 'вода'),
                      Metric(clock(b['elapsed']), 'время'),
                    ],
                  ),
                  const Divider(),
                  InfoRow('Оценка', b['rating']),
                  InfoRow('Метод', r['method']),
                  InfoRow('Пропорция', ratio(r)),
                  InfoRow('Температура', '${amount(r['temperature'])} °C'),
                  InfoRow('Помол', '${r['grind']} ${r['unit']}'),
                  InfoRow('Кофемолка', r['grinder']),
                  InfoRow('Воронка', r['dripper']),
                  InfoRow('Фильтр', r['filter']),
                  InfoRow(
                    'Вода',
                    (r['brewWater'] ?? '').isEmpty
                        ? 'Не указана'
                        : r['brewWater'],
                  ),
                  if (b['repeat'] == true)
                    const InfoRow('Повторить', 'Да, хочу ещё'),
                ],
              ),
            ),
            const SectionLabel('Заметка о вкусе'),
            Text(
              (b['note'] ?? '').isEmpty ? 'Без заметки' : b['note'],
              style: const TextStyle(fontSize: 14, height: 1.7),
            ),
            if ((b['next'] ?? '').isNotEmpty) ...[
              const SectionLabel('В следующий раз'),
              Text(
                b['next'],
                style: const TextStyle(fontSize: 14, height: 1.7),
              ),
            ],
            if ((b['taste'] as Map? ?? {}).isNotEmpty) ...[
              const SectionLabel('Вкус'),
              for (final entry in (b['taste'] as Map).entries)
                InfoRow(entry.key, '${amount(entry.value)} / 5'),
            ],
            const SectionLabel('План вливаний'),
            Text(
              'Суммарный вес воды на весах',
              style: TextStyle(color: context.colors.muted, fontSize: 11),
            ),
            for (final s in (b['plannedRecipe'] ?? r)['steps'])
              InfoRow(clock(s['time']), 'до ${amount(s['water'])} г'),
            const SizedBox(height: 24),
            Primary(
              'Повторить',
              icon: Icons.replay,
              onPressed: () => openRecipe(
                context,
                store,
                b['packId'],
                recipe: r,
                fromBrew: true,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => saveAsRecipe(context, store, b),
              child: const Text('Сохранить отдельным рецептом'),
            ),
            if (previous.isNotEmpty) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final other = await showModalBottomSheet<String>(
                    context: context,
                    showDragHandle: true,
                    builder: (ctx) => SafeArea(
                      child: ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text(
                              'С какой чашкой сравнить?',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          for (final p in previous)
                            ListTile(
                              title: Text(
                                '${dateLabel(p['date'])} · ${clock(p['elapsed'])}',
                              ),
                              subtitle: Text(
                                '${p['recipe']['grind']} ${p['recipe']['unit']} · ${p['rating']}',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.pop(ctx, p['id']),
                            ),
                        ],
                      ),
                    ),
                  );
                  if (other != null && context.mounted) {
                    push(
                      context,
                      ComparePage(store: store, brewIds: [other, brewId]),
                    );
                  }
                },
                icon: const Icon(Icons.compare_arrows, size: 18),
                label: const Text('Сравнить с другой чашкой'),
              ),
            ],
          ],
        ),
      );
    },
  );
}

class ComparePage extends StatelessWidget {
  final BloomStore store;
  final List<String> brewIds;
  const ComparePage({super.key, required this.store, required this.brewIds});
  @override
  Widget build(BuildContext context) {
    final attempts =
        brewIds
            .map((id) => store.brews.firstWhere((b) => b['id'] == id))
            .toList()
          ..sort((a, b) => (a['date'] as String).compareTo(b['date']));
    final a = attempts[0],
        b = attempts[1],
        ar = a['recipe'] as Json,
        br = b['recipe'] as Json;
    Widget row(
      String label,
      String left,
      String right, {
      bool highlight = false,
    }) {
      final changed = highlight && left != right;
      return Container(
        decoration: BoxDecoration(
          color: changed ? context.colors.track : context.colors.surface,
          border: Border(bottom: BorderSide(color: context.colors.line)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: changed ? context.colors.ink : context.colors.muted,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(flex: 3, child: Text(left, style: mono(11))),
            const SizedBox(width: 8),
            Expanded(flex: 3, child: Text(right, style: mono(11))),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Сравнение чашек')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          24, 16, 24, 32 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Text(
            store.pack(a['packId'])['name'],
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Один кофе, два эксперимента.',
            style: TextStyle(color: context.colors.muted, fontSize: 13),
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: [
                Container(
                  color: context.colors.accent,
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Text(
                          'Параметр',
                          style: TextStyle(
                            color: context.colors.onAccent,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Чашка 01',
                          style: TextStyle(
                            color: context.colors.onAccent,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Чашка 02',
                          style: TextStyle(
                            color: context.colors.onAccent,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                row('Дата', dateLabel(a['date']), dateLabel(b['date'])),
                row(
                  'Кофе',
                  '${amount(ar['dose'])} г',
                  '${amount(br['dose'])} г',
                ),
                row(
                  'Вода',
                  '${amount(ar['water'])} г',
                  '${amount(br['water'])} г',
                ),
                row(
                  'Помол',
                  '${ar['grind']} ${ar['unit']}',
                  '${br['grind']} ${br['unit']}',
                  highlight: true,
                ),
                row(
                  'Температура',
                  '${amount(ar['temperature'])} °C',
                  '${amount(br['temperature'])} °C',
                  highlight: true,
                ),
                row('Пропорция', ratio(ar), ratio(br), highlight: true),
                row(
                  'Время',
                  clock(a['elapsed']),
                  clock(b['elapsed']),
                  highlight: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.circle, size: 9, color: context.colors.track),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Различия выделены фоном',
                  style: TextStyle(color: context.colors.muted, fontSize: 11),
                ),
              ),
            ],
          ),
          for (var i = 0; i < 2; i++) ...[
            SectionLabel('Чашка 0${i + 1} · ${attempts[i]['rating']}'),
            Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attempts[i]['recipe']['name'],
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    (attempts[i]['note'] ?? '').isEmpty
                        ? 'Без заметки о вкусе'
                        : attempts[i]['note'],
                    style: const TextStyle(fontSize: 13, height: 1.6),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => openRecipe(
                      context,
                      store,
                      attempts[i]['packId'],
                      recipe: attempts[i]['recipe'],
                      fromBrew: true,
                    ),
                    icon: const Icon(Icons.replay, size: 18),
                    label: const Text('Повторить эту чашку'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            'Сравнивайте параметры и свои впечатления. Причины изменения вкуса остаются вашим наблюдением.',
            style: TextStyle(
              color: context.colors.muted,
              fontSize: 11,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
