import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'database_helper.dart';

/// 学习报告服务
class LearningReportService {
  static final LearningReportService instance = LearningReportService._();
  LearningReportService._();

  /// 生成周报数据
  Future<WeeklyReport> generateWeeklyReport() async {
    final db = await DatabaseHelper.database;
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));

    // 获取本周每日学习数据
    final dailyData = <DailyLearningData>[];
    for (int i = 0; i < 7; i++) {
      final date = weekStart.add(Duration(days: i));
      final dateStr = _formatDate(date);

      // 查询当天学习时间
      final timeResult = await db.query(
        'DailyLearnInfo',
        where: 'LearnDate = ?',
        whereArgs: [dateStr],
      );

      int learnTime = 0;
      if (timeResult.isNotEmpty) {
        learnTime = timeResult.first['LearnTime'] as int? ?? 0;
      }

      // 查询当天新学单词数（根据CreateTime判断）
      final newWordsResult = await db.rawQuery('''
        SELECT COUNT(*) as count FROM WordItem
        WHERE date(UpdateTime/1000, 'unixepoch', 'localtime') = ?
        AND LearnStatus > 0
      ''', [dateStr]);

      int newWords = 0;
      if (newWordsResult.isNotEmpty) {
        newWords = newWordsResult.first['count'] as int? ?? 0;
      }

      dailyData.add(DailyLearningData(
        date: date,
        learnTimeMinutes: (learnTime / 60).round(),
        newWords: newWords,
        reviewWords: 0, // 可以后续补充
      ));
    }

    // 计算总体统计
    final totalTime = dailyData.fold<int>(0, (sum, d) => sum + d.learnTimeMinutes);
    final totalNewWords = dailyData.fold<int>(0, (sum, d) => sum + d.newWords);
    final daysLearned = dailyData.where((d) => d.learnTimeMinutes > 0).length;

    // 获取已掌握单词总数
    final masteredResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM WordItem WHERE LearnStatus = 2'
    );
    final totalMastered = masteredResult.first['count'] as int? ?? 0;

    return WeeklyReport(
      weekStart: weekStart,
      weekEnd: weekStart.add(const Duration(days: 6)),
      dailyData: dailyData,
      totalTimeMinutes: totalTime,
      totalNewWords: totalNewWords,
      daysLearned: daysLearned,
      totalMastered: totalMastered,
    );
  }

  /// 生成月报数据
  Future<MonthlyReport> generateMonthlyReport({int? year, int? month}) async {
    final db = await DatabaseHelper.database;
    final now = DateTime.now();
    year ??= now.year;
    month ??= now.month;

    final monthStart = DateTime(year, month, 1);
    final monthEnd = DateTime(year, month + 1, 0); // 月末

    // 获取每周数据
    final weeklyData = <WeeklySummary>[];
    var weekStart = monthStart;

    while (weekStart.isBefore(monthEnd) || weekStart.isAtSameMomentAs(monthEnd)) {
      var weekEnd = weekStart.add(const Duration(days: 6));
      if (weekEnd.isAfter(monthEnd)) weekEnd = monthEnd;

      int weekTime = 0;
      int weekNewWords = 0;

      for (var date = weekStart;
          !date.isAfter(weekEnd);
          date = date.add(const Duration(days: 1))) {
        final dateStr = _formatDate(date);

        final timeResult = await db.query(
          'DailyLearnInfo',
          where: 'LearnDate = ?',
          whereArgs: [dateStr],
        );

        if (timeResult.isNotEmpty) {
          weekTime += timeResult.first['LearnTime'] as int? ?? 0;
        }
      }

      weeklyData.add(WeeklySummary(
        weekStart: weekStart,
        weekEnd: weekEnd,
        totalTimeMinutes: (weekTime / 60).round(),
        newWords: weekNewWords,
      ));

      weekStart = weekEnd.add(const Duration(days: 1));
    }

    // 计算月度总计
    final totalTime = weeklyData.fold<int>(0, (sum, w) => sum + w.totalTimeMinutes);

    // 获取月初和月末的掌握数对比
    final masteredResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM WordItem WHERE LearnStatus = 2'
    );
    final currentMastered = masteredResult.first['count'] as int? ?? 0;

    // 获取学习天数
    final daysResult = await db.rawQuery('''
      SELECT COUNT(DISTINCT LearnDate) as count FROM DailyLearnInfo
      WHERE LearnDate >= ? AND LearnDate <= ?
    ''', [_formatDate(monthStart), _formatDate(monthEnd)]);
    final daysLearned = daysResult.first['count'] as int? ?? 0;

    return MonthlyReport(
      year: year,
      month: month,
      weeklyData: weeklyData,
      totalTimeMinutes: totalTime,
      daysLearned: daysLearned,
      totalMastered: currentMastered,
    );
  }

  /// 将Widget截图保存为图片
  Future<String?> captureWidgetToImage(GlobalKey key, String fileName) async {
    try {
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final bytes = byteData.buffer.asUint8List();

      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}${Platform.pathSeparator}$fileName';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      return filePath;
    } catch (e) {
      debugPrint('Capture error: $e');
      return null;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

/// 周报数据
class WeeklyReport {
  final DateTime weekStart;
  final DateTime weekEnd;
  final List<DailyLearningData> dailyData;
  final int totalTimeMinutes;
  final int totalNewWords;
  final int daysLearned;
  final int totalMastered;

  WeeklyReport({
    required this.weekStart,
    required this.weekEnd,
    required this.dailyData,
    required this.totalTimeMinutes,
    required this.totalNewWords,
    required this.daysLearned,
    required this.totalMastered,
  });

  String get dateRangeText {
    return '${weekStart.month}/${weekStart.day} - ${weekEnd.month}/${weekEnd.day}';
  }

  String get totalTimeText {
    if (totalTimeMinutes >= 60) {
      return '${totalTimeMinutes ~/ 60}小时${totalTimeMinutes % 60}分钟';
    }
    return '$totalTimeMinutes 分钟';
  }
}

/// 月报数据
class MonthlyReport {
  final int year;
  final int month;
  final List<WeeklySummary> weeklyData;
  final int totalTimeMinutes;
  final int daysLearned;
  final int totalMastered;

  MonthlyReport({
    required this.year,
    required this.month,
    required this.weeklyData,
    required this.totalTimeMinutes,
    required this.daysLearned,
    required this.totalMastered,
  });

  String get monthText => '$year年$month月';

  String get totalTimeText {
    if (totalTimeMinutes >= 60) {
      final hours = totalTimeMinutes ~/ 60;
      final mins = totalTimeMinutes % 60;
      return '$hours小时${mins > 0 ? '$mins分钟' : ''}';
    }
    return '$totalTimeMinutes 分钟';
  }
}

/// 每日学习数据
class DailyLearningData {
  final DateTime date;
  final int learnTimeMinutes;
  final int newWords;
  final int reviewWords;

  DailyLearningData({
    required this.date,
    required this.learnTimeMinutes,
    required this.newWords,
    required this.reviewWords,
  });

  String get weekdayName {
    const names = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return names[date.weekday - 1];
  }

  String get dateText => '${date.month}/${date.day}';
}

/// 周汇总
class WeeklySummary {
  final DateTime weekStart;
  final DateTime weekEnd;
  final int totalTimeMinutes;
  final int newWords;

  WeeklySummary({
    required this.weekStart,
    required this.weekEnd,
    required this.totalTimeMinutes,
    required this.newWords,
  });

  String get weekText {
    return '${weekStart.month}/${weekStart.day}-${weekEnd.month}/${weekEnd.day}';
  }
}
