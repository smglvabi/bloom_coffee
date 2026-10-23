import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

Future<Database> openBloomDatabase({
  DatabaseFactory? factoryOverride,
  String path = 'bloom.db',
}) async {
  final factory =
      factoryOverride ?? (kIsWeb ? databaseFactoryFfiWeb : databaseFactory);
  return factory.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 1,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE packs (id TEXT PRIMARY KEY, data TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE recipes (id TEXT PRIMARY KEY, pack_id TEXT NOT NULL REFERENCES packs(id), data TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE brews (id TEXT PRIMARY KEY, pack_id TEXT NOT NULL REFERENCES packs(id), data TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE settings (id TEXT PRIMARY KEY, data TEXT NOT NULL)',
        );
        await db.execute('CREATE INDEX brews_pack ON brews(pack_id)');
        await db.execute('CREATE INDEX recipes_pack ON recipes(pack_id)');
      },
    ),
  );
}
