import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'lib/services/database_helper.dart';

void main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  
  final db = await DatabaseHelper.database;
  
  final result = await db.rawQuery("PRAGMA table_info(DailyLearnInfo)");
  for (var row in result) {
    debugPrint('${row['name']} (${row['type']})');
  }
  
  final sample = await db.query('WordBook', limit: 1);
  if (sample.isNotEmpty) {
    debugPrint('Sample Data: ${sample.first}');
  }
}
