import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'lib/services/database_helper.dart';

void main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  
  try {
    final db = await DatabaseHelper.database;
    
    debugPrint('--- DailyLearnInfo ---');
    try {
      final info = await db.query('DailyLearnInfo', limit: 5);
      if (info.isEmpty) {
        debugPrint('DailyLearnInfo is EMPTY.');
      } else {
        for (var row in info) {
          debugPrint(row.toString());
        }
      }
    } catch (e) {
      debugPrint('Error querying DailyLearnInfo: $e');
    }

    debugPrint('\n--- StudyLog (if exists) ---');
    try {
      final logs = await db.query('StudyLog', limit: 5); // Guessing table name
      if (logs.isEmpty) {
        debugPrint('StudyLog is EMPTY or does not exist (if no error above).');
      } else {
        debugPrint('Found StudyLog entries: ${logs.length}');
      }
    } catch (e) {
      debugPrint('Error querying StudyLog: $e');
    }

    debugPrint('\n--- Creating Data Mock Check ---');
    // If DailyLearnInfo is empty, can we generate data from WordItem updates?
    final learnedWords = await db.rawQuery('SELECT Count(*) as count FROM WordItem WHERE LearnStatus > 0');
    debugPrint('Total Learned Words: ${learnedWords.first['count']}');

  } catch (e) {
    debugPrint('General Error: $e');
  }
}
