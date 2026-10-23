part of '../app.dart';

class EquipmentPage extends StatelessWidget {
  final BloomStore store;
  const EquipmentPage({super.key, required this.store});
  Future<void> export(BuildContext context) async {
    await guard(context, () async {
      final box = context.findRenderObject() as RenderBox?;
      await exportJournal(
        store.exportJson(),
        box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      );
      if (context.mounted) toast(context, 'Файл журнала подготовлен');
    });
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
    children: [
      Text('Оборудование', style: Theme.of(context).textTheme.headlineLarge),
      SectionLabel(
        'Мои наборы',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: context.colors.ink,
        ),
      ),
      for (final kit in store.equipment)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tune, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        kit['name'],
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Редактировать набор',
                      onPressed: () => push(
                        context,
                        EquipmentEditor(store: store, kit: kit),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                    ),
                  ],
                ),
                const Divider(),
                for (final (label, value) in [
                  ('Кофемолка', kit['grinder']),
                  ('Настройка', kit['unit']),
                  ('Воронка', '${kit['dripper']} ${kit['size']}'),
                  ('Фильтры', kit['filter']),
                  (
                    'Вода',
                    (kit['water'] ?? '').isEmpty ? 'Не указана' : kit['water'],
                  ),
                ])
                  InfoRow(
                    label,
                    value,
                    labelFlex: 2,
                    valueFlex: 3,
                    labelStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: context.colors.muted,
                    ),
                    valueStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.colors.ink,
                    ),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: kit['id'] == store.defaultKit
                        ? null
                        : () => guard(
                            context,
                            () =>
                                store.saveEquipment(store.equipment, kit['id']),
                          ),
                    icon: Icon(
                      kit['id'] == store.defaultKit
                          ? Icons.check_circle_outline
                          : Icons.circle_outlined,
                      size: 18,
                    ),
                    label: Text(
                      kit['id'] == store.defaultKit
                          ? 'Набор по умолчанию'
                          : 'Использовать по умолчанию',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      OutlinedButton.icon(
        onPressed: () => push(context, EquipmentEditor(store: store)),
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Добавить набор'),
      ),
      const SizedBox(height: 12),
      Text(
        'Набор по умолчанию подставляется в новые рецепты. Сохранённые чашки остаются без изменений.',
        style: TextStyle(
          color: context.colors.muted,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          height: 1.6,
        ),
      ),
      SectionLabel(
        'Оформление',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: context.colors.ink,
        ),
      ),
      InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Тема',
          prefixIcon: Icon(Icons.contrast_outlined),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<ThemeMode>(
            key: const ValueKey('theme-selector'),
            value: store.themeMode,
            isExpanded: true,
            isDense: true,
            borderRadius: BorderRadius.circular(12),
            dropdownColor: context.colors.surface,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            items: const [
              DropdownMenuItem(
                value: ThemeMode.system,
                child: Text('Системная'),
              ),
              DropdownMenuItem(value: ThemeMode.light, child: Text('Светлая')),
              DropdownMenuItem(value: ThemeMode.dark, child: Text('Тёмная')),
            ],
            onChanged: (mode) {
              if (mode != null) guard(context, () => store.setThemeMode(mode));
            },
          ),
        ),
      ),
      SectionLabel(
        'Ваши данные',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: context.colors.ink,
        ),
      ),
      Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.file_download_outlined, size: 26),
            const SizedBox(height: 14),
            Text(
              'Журнал всегда с вами',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Скачайте пачки, рецепты и заваривания в JSON. Все параметры и заметки сохранятся.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: context.colors.muted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            Primary(
              'Экспортировать журнал',
              icon: Icons.download_outlined,
              onPressed: () => export(context),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, size: 16, color: context.colors.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Данные хранятся на этом устройстве.\nБез регистрации и облачной синхронизации.',
              style: TextStyle(
                color: context.colors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 28),
      Center(
        child: Text(
          'Bloom  /  1.1.0',
          style: TextStyle(
            color: context.colors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ],
  );
}

class EquipmentEditor extends StatefulWidget {
  final BloomStore store;
  final Json? kit;
  const EquipmentEditor({super.key, required this.store, this.kit});
  @override
  State<EquipmentEditor> createState() => _EquipmentEditorState();
}

class _EquipmentEditorState extends State<EquipmentEditor> {
  final f = FormFields();
  final form = GlobalKey<FormState>();
  bool selected = false, busy = false;
  @override
  void initState() {
    super.initState();
    for (final key in [
      'name',
      'grinder',
      'unit',
      'dripper',
      'size',
      'filter',
      'water',
    ]) {
      f.c(key, widget.kit?[key] ?? '');
    }
    selected = widget.kit?['id'] == widget.store.defaultKit;
  }

  @override
  void dispose() {
    f.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate() || busy) return;
    setState(() => busy = true);
    await guard(context, () async {
      final kit = <String, dynamic>{
        'id': widget.kit?['id'] ?? uid(),
        for (final key in f.controllers.keys) key: f.text(key),
      };
      final items = widget.store.equipment.map(clone).toList();
      final index = items.indexWhere((e) => e['id'] == kit['id']);
      if (index == -1) {
        items.add(kit);
      } else {
        items[index] = kit;
      }
      await widget.store.saveEquipment(
        items,
        selected ? kit['id'] : widget.store.defaultKit,
      );
      if (mounted) {
        toast(context, 'Набор сохранён');
        Navigator.pop(context);
      }
    });
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.kit == null ? 'Новый набор' : 'Ваш набор'),
    ),
    body: Form(
      key: form,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          24, 16, 24, 32 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          f.field('name', 'Название набора', required: true),
          f.field('grinder', 'Кофемолка', required: true),
          f.field('unit', 'Единицы настройки помола', required: true),
          f.field('dripper', 'Воронка', required: true),
          f.field('size', 'Размер воронки', required: true),
          f.field('filter', 'Фильтры', required: true),
          f.field('water', 'Вода · необязательно'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Набор по умолчанию',
              style: TextStyle(fontSize: 14),
            ),
            value: selected,
            onChanged: widget.kit?['id'] == widget.store.defaultKit
                ? null
                : (value) => setState(() => selected = value),
          ),
          const SizedBox(height: 24),
          Primary(
            busy ? 'Сохраняем…' : 'Сохранить набор',
            onPressed: busy ? null : save,
          ),
        ],
      ),
    ),
  );
}
