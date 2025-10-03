import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class PendingTripQueue {
  static const String _dbName = 'pending_trips.db';
  static const int _dbVersion = 1;
  static const String _table = 'pending_trips';

  Database? _db;
  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  Future<String> _getOrCreateDbKey() async {
    const keyName = 'pending_trips_key';
    String? key = await _secure.read(key: keyName);
    if (key == null || key.isEmpty) {
      key = List.generate(
        32,
        (i) => (i * 11 + 5) % 256,
      ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      await _secure.write(key: keyName, value: key);
    }
    return key;
  }

  Future<Database> _open() async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, _dbName);
    final key = await _getOrCreateDbKey();
    _db = await openDatabase(
      dbPath,
      version: _dbVersion,
      password: key,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            payload TEXT NOT NULL,
            created_at_ms INTEGER NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }

  Future<void> enqueue(Map<String, dynamic> tripPayload) async {
    final db = await _open();
    await db.insert(_table, {
      'payload': jsonEncode(tripPayload),
      'created_at_ms': DateTime.now().millisecondsSinceEpoch,
    });
    await _trimIfTooLarge(maxRows: 500);
  }

  Future<List<Map<String, dynamic>>> peekAll() async {
    final db = await _open();
    return db.query(_table, orderBy: 'id ASC');
  }

  Future<void> deleteByIds(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await _open();
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.delete(_table, where: 'id IN ($placeholders)', whereArgs: ids);
  }

  Future<void> _trimIfTooLarge({required int maxRows}) async {
    final db = await _open();
    final res = await db.rawQuery('SELECT COUNT(*) as c FROM $_table');
    final c = (res.first['c'] as int?) ?? 0;
    if (c <= maxRows) return;
    final toDelete = c - maxRows;
    await db.rawDelete(
      'DELETE FROM $_table WHERE id IN (SELECT id FROM $_table ORDER BY id ASC LIMIT ?)',
      [toDelete],
    );
    await db.execute('VACUUM');
  }
}


