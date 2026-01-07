import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../services/database_helper.dart';

/// Repository for learning statistics
class StatsRepository {
  Database? _database;
  
  Future<Database> get _db async {
    _database ??= await DatabaseHelper.database;
    return _database!;
  }

  /// Get home page statistics
  Future<Map<String, dynamic>> getHomeStats() async {
    final db = await _db;
    
    try {
      final rows = await db.query(
        'DailyLearnInfo',
        orderBy: 'LearnDate DESC',
        limit: 365,
      );
      
      int todayDuration = 0;
      int totalDays = rows.length;
      
      final Map<DateTime, int> heatmapData = {};
      final now = DateTime.now();
      final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      
      for (var row in rows) {
        final dateVal = row['LearnDate'];
        String dateStr = '';
        if (dateVal is String) dateStr = dateVal;
        
        final duration = row['LearnTime'] as int? ?? 0;
        
        DateTime? date;
        try {
          if (dateStr.contains('-')) {
            date = DateTime.parse(dateStr);
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Failed to parse date: $dateStr, error: $e');
          }
        }
        
        if (date != null) {
          heatmapData[date] = (duration / 60).round();
          if (dateStr == todayStr) {
            todayDuration = duration;
          }
        }
      }
      
      return {
        'todayDuration': (todayDuration / 60).round(),
        'totalDays': totalDays,
        'heatmap': heatmapData,
      };
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting home stats: $e');
      }
      return {
        'todayDuration': 0,
        'totalDays': 0,
        'heatmap': <DateTime, int>{},
      };
    }
  }

  /// Update daily learning info
  Future<void> updateDailyLearnInfo({int addSeconds = 30}) async {
    final db = await _db;
    final now = DateTime.now();
    final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    
    try {
      final rows = await db.query(
        'DailyLearnInfo',
        where: 'LearnDate = ?',
        whereArgs: [dateStr],
      );
      
      if (rows.isNotEmpty) {
        final currentDuration = rows.first['LearnTime'] as int? ?? 0;
        await db.update(
          'DailyLearnInfo',
          {
            'LearnTime': currentDuration + addSeconds,
            'UpdateTime': now.millisecondsSinceEpoch,
          },
          where: 'LearnDate = ?',
          whereArgs: [dateStr],
        );
      } else {
        await db.insert('DailyLearnInfo', {
          'LearnDate': dateStr,
          'LearnTime': addSeconds,
          'ContinuityDays': 1,
          'UpdateTime': now.millisecondsSinceEpoch,
        });
      }
    } catch (e) {
      // Table might not exist, ignore
      if (kDebugMode) {
        debugPrint('Error updating daily learn info: $e');
      }
    }
  }

  /// Get learning streak (consecutive days)
  Future<int> getLearningStreak() async {
    final db = await _db;
    
    try {
      final rows = await db.query(
        'DailyLearnInfo',
        orderBy: 'LearnDate DESC',
        limit: 365,
      );
      
      if (rows.isEmpty) return 0;
      
      int streak = 0;
      DateTime? expectedDate = DateTime.now();
      
      for (var row in rows) {
        final dateStr = row['LearnDate'] as String?;
        if (dateStr == null) continue;
        
        try {
          final date = DateTime.parse(dateStr);
          final diff = expectedDate!.difference(date).inDays;
          
          if (diff == 0 || diff == 1) {
            streak++;
            expectedDate = date;
          } else {
            break;
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Failed to parse date: $dateStr, error: $e');
          }
        }
      }
      
      return streak;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting learning streak: $e');
      }
      return 0;
    }
  }
}
