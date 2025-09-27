import 'dart:async';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LocalLocationQueue {
  static const String _dbName = 'location_queue.db';
  static const int _dbVersion = 1;
  static const String _table = 'pending_locations';

  Database? _db;
  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  Future<String> _getOrCreateDbKey() async {
    const keyName = 'loc_queue_key';
    String? key = await _secure.read(key: keyName);
    if (key == null || key.isEmpty) {
      // 32-byte key as hex string
      key = List.generate(32, (i) => (i * 13 + 7) % 256)
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
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
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            accuracy REAL,
            timestamp_ms INTEGER NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }

  Future<void> enqueue({
    required double latitude,
    required double longitude,
    double? accuracy,
    required int timestampMs,
  }) async {
    final db = await _open();
    await db.insert(_table, {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'timestamp_ms': timestampMs,
    });
    await _trimIfTooLarge(maxRows: 2000);
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

  Future<void> clear() async {
    final db = await _open();
    await db.delete(_table);
  }

  Future<int> count() async {
    final db = await _open();
    final res = await db.rawQuery('SELECT COUNT(*) as c FROM $_table');
    final c = res.first['c'] as int?;
    return c ?? 0;
  }

  Future<void> _trimIfTooLarge({required int maxRows}) async {
    final db = await _open();
    final res = await db.rawQuery('SELECT COUNT(*) as c FROM $_table');
    final c = (res.first['c'] as int?) ?? 0;
    if (c <= maxRows) return;
    final toDelete = c - maxRows;
    // Delete the oldest rows
    await db.rawDelete('DELETE FROM $_table WHERE id IN (SELECT id FROM $_table ORDER BY id ASC LIMIT ?)', [toDelete]);
  }

  Future<void> cleanupOldEntries() async {
    final db = await _open();
    // Remove entries older than 3 days to save storage
    final cutoffTime = DateTime.now().subtract(const Duration(days: 3)).millisecondsSinceEpoch;
    await db.delete(_table, where: 'timestamp_ms < ?', whereArgs: [cutoffTime]);
  }
}


