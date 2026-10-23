import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:bloom/database.dart';
import 'package:bloom/domain.dart';
import 'package:bloom/store.dart';

void main() {
  late BloomStore store;
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    final db = await openBloomDatabase(
      factoryOverride: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    store = BloomStore(db);
    await store.load();
  });
  tearDown(() async {
    store.dispose();
    await store.db.close();
  });
  Json brew(String id, {double dose = 15}) => {
    'id': id,
    'packId': 'sidamo',
    'recipe': clone(store.recipes.first)..['dose'] = dose,
    'date': DateTime.now().toIso8601String(),
    'elapsed': 180,
    'rating': 'Понравилось',
    'favorite': false,
    'repeat': true,
    'note': 'Персик',
    'next': 'Помол крупнее',
    'taste': <String, dynamic>{},
  };
  test(
    'Demo balance agrees with three 15g brews; seeding is idempotent',
    () async {
      expect(store.packs.length, 2);
      expect(store.brews.length, 3);
      expect(store.pack('sidamo')['remaining'], 205);
      await store.load();
      expect(store.brews.length, 3);
    },
  );
  test('Starting and cancelling do not consume coffee', () async {
    await store.start(store.recipes.first);
    final restored = BloomStore(store.db);
    await restored.load();
    expect(restored.session!['id'], store.session!['id']);
    expect(restored.session!['recipe']['water'], 250);
    await store.cancelSession();
    expect(store.pack('sidamo')['remaining'], 205);
    expect(store.brews.length, 3);
    expect(store.session, isNull);
    restored.dispose();
  });
  test('Saving twice consumes the actual dose exactly once', () async {
    final result = brew('one', dose: 16.5);
    expect(await store.saveBrew(result), true);
    expect(await store.saveBrew(result), false);
    expect(store.pack('sidamo')['remaining'], 188.5);
    expect(store.brews.length, 4);
    expect(store.pack('sidamo')['next'], 'Помол крупнее');
    final restored = BloomStore(store.db);
    await restored.load();
    expect(restored.pack('sidamo')['remaining'], 188.5);
    expect(restored.brews.first['rating'], 'Понравилось');
    restored.dispose();
  });
  test('Insufficient stock rolls back both history and balance', () async {
    await store.savePack(clone(store.pack('sidamo'))..['remaining'] = 10.0);
    await expectLater(
      store.saveBrew(brew('too-much')),
      throwsA(isA<InsufficientCoffee>()),
    );
    expect(store.brews.length, 3);
    expect(store.pack('sidamo')['remaining'], 10);
  });
  test('Editing the plan never changes historical snapshots', () async {
    final before = jsonEncode(store.brews);
    await store.saveRecipe(
      clone(store.recipes.first)
        ..['dose'] = 20.0
        ..['water'] = 333.0
        ..['grind'] = '25',
    );
    expect(jsonEncode(store.brews), before);
    expect(store.pack('sidamo')['remaining'], 205);
  });
  test('Archiving and changing defaults preserve existing recipes', () async {
    await store.savePack(clone(store.pack('sidamo'))..['archived'] = true);
    final kit = defaultEquipment()
      ..['id'] = 'other'
      ..['grinder'] = 'Другая кофемолка';
    await store.saveEquipment([store.kit, kit], 'other');
    expect(newRecipe('huila', store.kit)['grinder'], 'Другая кофемолка');
    expect(store.recipes.first['grinder'], 'Timemore C3');
    expect(store.pack('sidamo')['archived'], true);
    final export = jsonDecode(store.exportJson());
    expect(export['brews'].length, 3);
    expect(export['packs'].length, 2);
  });
}
