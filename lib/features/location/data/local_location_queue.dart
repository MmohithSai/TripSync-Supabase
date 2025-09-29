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
    
    // Vacuum the database to reclaim space
    await db.execute('VACUUM');
  }

  Future<void> cleanupOldEntries() async {
    final db = await _open();
    // Remove entries older than 2 days to save storage (reduced from 3 days)
    final cutoffTime = DateTime.now().subtract(const Duration(days: 2)).millisecondsSinceEpoch;
    await db.delete(_table, where: 'timestamp_ms < ?', whereArgs: [cutoffTime]);
    
    // Vacuum after cleanup to reclaim space
    await db.execute('VACUUM');
  }
  
  /// Get storage usage statistics
  Future<Map<String, int>> getStorageStats() async {
    final db = await _open();
    final countResult = await db.rawQuery('SELECT COUNT(*) as count FROM $_table');
    final count = countResult.first['count'] as int;
    
    final sizeResult = await db.rawQuery('SELECT page_count * page_size as size FROM pragma_page_count(), pragma_page_size()');
    final size = sizeResult.first['size'] as int;
    
    return {
      'rowCount': count,
      'sizeBytes': size,
    };
  }
  
  /// Optimize storage by removing duplicate nearby locations
  Future<void> optimizeStorage() async {
    final db = await _open();
    
    // Remove locations that are very close to each other (within 10 meters)
    // Keep only the most recent one
    await db.execute('''
      DELETE FROM $_table 
      WHERE id NOT IN (
        SELECT MAX(id) 
        FROM $_table t1 
        WHERE EXISTS (
          SELECT 1 FROM $_table t2 
          WHERE t2.id != t1.id 
          AND ABS(t1.latitude - t2.latitude) < 0.0001 
          AND ABS(t1.longitude - t2.longitude) < 0.0001
          AND t1.timestamp_ms <= t2.timestamp_ms
        )
      )
    ''');
    
    // Vacuum after optimization
    await db.execute('VACUUM');
  }
}


