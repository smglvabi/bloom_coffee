import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:sqflite_common/sqlite_api.dart';
import 'domain.dart';

class BloomStore extends ChangeNotifier {
  final Database db;
  BloomStore(this.db);
  List<Json> packs = [], recipes = [], brews = [];
  List<Json> equipment = [];
  String defaultKit = 'default';
  ThemeMode themeMode = ThemeMode.system;
  Json? session;

  Json get kit => equipment.firstWhere(
    (e) => e['id'] == defaultKit,
    orElse: () => equipment.first,
  );
  Json pack(String id) => packs.firstWhere((p) => p['id'] == id);
  List<Json> packBrews(String id) =>
      brews.where((b) => b['packId'] == id).toList();
  List<Json> packRecipes(String id) =>
      recipes.where((r) => r['packId'] == id).toList();
  Json? last(String id) => packBrews(id).firstOrNull;
  Json? favorite(String id) =>
      packBrews(id).where((b) => b['favorite'] == true).firstOrNull;

  Future<void> load() async {
    Future<List<Json>> rows(String table) async => (await db.query(
      table,
    )).map((r) => jsonDecode(r['data'] as String) as Json).toList();
    packs = await rows('packs');
    recipes = await rows('recipes');
    brews = await rows('brews');
    brews.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
    final settings = await db.query('settings');
    Json? setting(String id) {
      final row = settings.where((r) => r['id'] == id).firstOrNull;
      return row == null ? null : jsonDecode(row['data'] as String) as Json;
    }

    final kits = setting('equipment');
    equipment = kits == null
        ? [defaultEquipment()]
        : (kits['items'] as List).cast<Json>();
    defaultKit = kits?['default'] ?? 'default';
    final savedTheme = setting('appearance')?['theme'];
    themeMode =
        ThemeMode.values.where((mode) => mode.name == savedTheme).firstOrNull ??
        ThemeMode.system;
    session = setting('session');
    if (setting('seeded') == null) {
      await _seed();
      return load();
    }
    notifyListeners();
  }

  Future<void> _put(DatabaseExecutor tx, String table, Json data) async {
    await tx.insert(table, {
      'id': data['id'],
      if (table == 'recipes' || table == 'brews') 'pack_id': data['packId'],
      'data': jsonEncode(data),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> setting(String id, Json data) async {
    await db.insert('settings', {
      'id': id,
      'data': jsonEncode(data),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> savePack(Json data) async {
    // UPDATE instead of REPLACE preserves foreign-key references.
    final count = await db.update(
      'packs',
      {'data': jsonEncode(data)},
      where: 'id = ?',
      whereArgs: [data['id']],
    );
    if (count == 0) await _put(db, 'packs', data);
    await load();
  }

  Future<void> saveRecipe(Json data) async {
    await _put(db, 'recipes', data);
    await load();
  }

  Future<void> saveEquipment(List<Json> items, String selected) async {
    await setting('equipment', {'items': items, 'default': selected});
    await load();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await setting('appearance', {'theme': mode.name});
    themeMode = mode;
    notifyListeners();
  }

  Future<void> start(Json recipe, {bool manual = false}) async {
    if (session != null) throw StateError('Уже есть незавершённое заваривание');
    await setting('session', {
      'id': uid(),
      'recipe': clone(recipe),
      'started': DateTime.now().toIso8601String(),
      'state': manual ? 'result' : 'timer',
      'elapsed': manual ? recipe['duration'] : 0,
      'sound': false,
    });
    await load();
  }

  Future<void> updateSession(Json data) async {
    await setting('session', data);
    session = clone(data);
    notifyListeners();
  }

  Future<void> cancelSession() async {
    await db.delete('settings', where: 'id = ?', whereArgs: ['session']);
    session = null;
    notifyListeners();
  }

  /// The unique session id and inventory update share one SQLite transaction.
  /// Retries (including a second browser tab) cannot consume coffee twice.
  Future<bool> saveBrew(Json brew) async {
    final created = await db.transaction((tx) async {
      if ((await tx.query(
        'brews',
        where: 'id = ?',
        whereArgs: [brew['id']],
      )).isNotEmpty) {
        return false;
      }
      final row = (await tx.query(
        'packs',
        where: 'id = ?',
        whereArgs: [brew['packId']],
      )).single;
      final p = jsonDecode(row['data'] as String) as Json;
      final dose = number(brew['recipe']['dose']);
      if (!dose.isFinite || dose <= 0) throw ArgumentError('Некорректная доза');
      final remaining = number(p['remaining']);
      if (remaining < dose) throw InsufficientCoffee(remaining);
      p['remaining'] = double.parse((remaining - dose).toStringAsFixed(2));
      if ((brew['next'] as String? ?? '').trim().isNotEmpty) {
        p['next'] = brew['next'];
      }
      await tx.update(
        'packs',
        {'data': jsonEncode(p)},
        where: 'id = ?',
        whereArgs: [p['id']],
      );
      await _put(tx, 'brews', clone(brew));
      await tx.delete('settings', where: 'id = ?', whereArgs: ['session']);
      return true;
    });
    await load();
    return created;
  }

  Future<void> toggleFavorite(Json brew) async {
    final copy = clone(brew)..['favorite'] = brew['favorite'] != true;
    await _put(db, 'brews', copy);
    await load();
  }

  String exportJson() => const JsonEncoder.withIndent('  ').convert({
    'app': 'Bloom',
    'version': 1,
    'exportedAt': DateTime.now().toIso8601String(),
    'packs': packs,
    'recipes': recipes,
    'brews': brews,
    'equipment': equipment,
  });

  Future<void> _seed() async {
    final now = DateTime.now();
    String ago(int days) =>
        now.subtract(Duration(days: days)).toIso8601String();
    final p1 = {
      'id': 'sidamo',
      'name': 'Эфиопия Сидамо',
      'roaster': 'Тихий обжарщик',
      'country': 'Эфиопия',
      'process': 'Мытая',
      'mass': 250.0,
      'remaining': 205.0,
      'roastDate': ago(16),
      'openDate': ago(5),
      'notes': 'Бергамот, белые цветы, персик',
      'next': 'Попробовать чуть крупнее помол — 19 кликов.',
      'archived': false,
      'cover': 0,
    };
    final p2 = {
      'id': 'huila',
      'name': 'Колумбия Уила',
      'roaster': 'Северный склон',
      'country': 'Колумбия',
      'process': 'Натуральная',
      'mass': 200.0,
      'remaining': 200.0,
      'roastDate': ago(12),
      'openDate': null,
      'notes': 'Красное яблоко, карамель, какао',
      'next': '',
      'archived': false,
      'cover': 1,
    };
    final recipe = newRecipe('sidamo', defaultEquipment())
      ..['id'] = 'morning'
      ..['name'] = 'Утренний V60';
    await db.transaction((tx) async {
      await _put(tx, 'packs', p1);
      await _put(tx, 'packs', p2);
      await _put(tx, 'recipes', recipe);
      for (var i = 0; i < 3; i++) {
        final snapshot = clone(recipe)
          ..['grind'] = '${20 - i}'
          ..['temperature'] = i == 0 ? 92.0 : 93.0;
        await _put(tx, 'brews', {
          'id': 'demo-$i',
          'packId': 'sidamo',
          'recipe': snapshot,
          'date': ago(3 - i),
          'elapsed': [165, 177, 180][i],
          'rating': i == 0 ? 'Нормально' : 'Понравилось',
          'repeat': i > 0,
          'favorite': i == 2,
          'note': [
            'Лёгкая, но немного не хватает сладости.',
            'Сладкий персик, чистое послевкусие.',
            'Бергамот и персик. Очень сбалансированная чашка.',
          ][i],
          'next': i == 2 ? 'Попробовать чуть крупнее помол — 19 кликов.' : '',
          'taste': {'Кислотность': 3.0, 'Сладость': 4.0, 'Тело': 2.0},
        });
      }
      await tx.insert('settings', {'id': 'seeded', 'data': '{}'});
    });
  }
}
