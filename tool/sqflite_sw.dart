// Rebuild with the app's locked dependencies if upgrading SQLite:
// dart compile js -O4 tool/sqflite_sw.dart -o web/sqflite_sw.js
// Also replace web/sqlite3.wasm with the matching sqlite3 release asset.
// ignore: implementation_imports
import 'package:sqflite_common_ffi_web/src/sw/shared_worker.dart';

void main(List<String> args) => mainSharedWorker(args);
