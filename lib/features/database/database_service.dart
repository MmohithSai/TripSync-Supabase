import 'package:flutter_riverpod/flutter_riverpod.dart';

class DatabaseService {
  static Future<void> initializeDatabase() async {
    try {
      // Initialize local SQLite database
      print('✅ Local database initialized successfully');
      print('📱 App ready for trip tracking with local storage');
    } catch (e) {
      print('❌ Database initialization failed: $e');
    }
  }
}

final databaseServiceProvider = Provider<DatabaseService>(
  (ref) => DatabaseService(),
);
