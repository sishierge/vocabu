import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 学习统计服务
class LearningStatisticsService {
  static final LearningStatisticsService instance = LearningStatisticsService._();
  LearningStatisticsService._();

  static const String _keyDailyStats = 'daily_learning_stats';
  static const String _keyTotalStats = 'total_learning_stats';

  DailyStats _todayStats = DailyStats.empty();
  TotalStats _totalStats = TotalStats.empty();
  bool _initialized = false;

  DailyStats get todayStats => _todayStats;
  TotalStats get totalStats => _totalStats;

  /// 初始化服务
  Future<void> initialize() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();

    // 加载今日统计
    final dailyJson = prefs.getString(_keyDailyStats);
    if (dailyJson != null) {
      final data = jsonDecode(dailyJson) as Map<String, dynamic>;
      _todayStats = DailyStats.fromJson(data);

      // 检查是否是新的一天
      if (!_todayStats.isToday) {
        // 将昨天的数据累加到总统计
        _totalStats = _totalStats.addDaily(_todayStats);
        await _saveTotalStats();
        _todayStats = DailyStats.empty();
        await _saveDailyStats();
      }
    }

    // 加载总统计
    final totalJson = prefs.getString(_keyTotalStats);
    if (totalJson != null) {
      final data = jsonDecode(totalJson) as Map<String, dynamic>;
      _totalStats = TotalStats.fromJson(data);
    }

    _initialized = true;
  }

  /// 记录学习时长（分钟）
  Future<void> addStudyTime(int minutes) async {
    _todayStats = _todayStats.copyWith(
      studyMinutes: _todayStats.studyMinutes + minutes,
    );
    await _saveDailyStats();
  }

  /// 记录练习句子数
  Future<void> addPracticedSentences(int count) async {
    _todayStats = _todayStats.copyWith(
      practicedSentences: _todayStats.practicedSentences + count,
    );
    await _saveDailyStats();
  }

  /// 记录听写正确数
  Future<void> addDictationResult(int correct, int total) async {
    _todayStats = _todayStats.copyWith(
      dictationCorrect: _todayStats.dictationCorrect + correct,
      dictationTotal: _todayStats.dictationTotal + total,
    );
    await _saveDailyStats();
  }

  /// 记录跟读得分
  Future<void> addPronunciationScore(double score) async {
    final newTotal = _todayStats.pronunciationScoreTotal + score;
    final newCount = _todayStats.pronunciationCount + 1;
    _todayStats = _todayStats.copyWith(
      pronunciationScoreTotal: newTotal,
      pronunciationCount: newCount,
    );
    await _saveDailyStats();
  }

  /// 记录播放次数
  Future<void> addPlayCount(int count) async {
    _todayStats = _todayStats.copyWith(
      playCount: _todayStats.playCount + count,
    );
    await _saveDailyStats();
  }

  /// 获取最近7天的统计数据
  Future<List<DailyStats>> getWeeklyStats() async {
    final prefs = await SharedPreferences.getInstance();
    final weeklyJson = prefs.getString('weekly_stats');

    if (weeklyJson != null) {
      final list = jsonDecode(weeklyJson) as List;
      return list.map((e) => DailyStats.fromJson(e)).toList();
    }

    // 返回包含今天数据的列表
    return [_todayStats];
  }

  /// 保存今日统计到每周记录
  Future<void> saveToWeekly() async {
    final prefs = await SharedPreferences.getInstance();
    final weeklyJson = prefs.getString('weekly_stats');

    List<DailyStats> weekly = [];
    if (weeklyJson != null) {
      final list = jsonDecode(weeklyJson) as List;
      weekly = list.map((e) => DailyStats.fromJson(e)).toList();
    }

    // 更新或添加今天的数据
    final todayIndex = weekly.indexWhere((s) => s.isToday);
    if (todayIndex >= 0) {
      weekly[todayIndex] = _todayStats;
    } else {
      weekly.add(_todayStats);
    }

    // 只保留最近7天
    if (weekly.length > 7) {
      weekly = weekly.sublist(weekly.length - 7);
    }

    await prefs.setString('weekly_stats', jsonEncode(weekly.map((s) => s.toJson()).toList()));
  }

  Future<void> _saveDailyStats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDailyStats, jsonEncode(_todayStats.toJson()));
    await saveToWeekly();
  }

  Future<void> _saveTotalStats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTotalStats, jsonEncode(_totalStats.toJson()));
  }

  /// 获取连续学习天数
  Future<int> getStreakDays() async {
    final weekly = await getWeeklyStats();
    int streak = 0;
    final now = DateTime.now();

    for (int i = 0; i < 30; i++) {
      final checkDate = now.subtract(Duration(days: i));
      final hasStudy = weekly.any((s) =>
        s.date.year == checkDate.year &&
        s.date.month == checkDate.month &&
        s.date.day == checkDate.day &&
        s.studyMinutes > 0
      );

      if (hasStudy) {
        streak++;
      } else if (i > 0) {
        break;
      }
    }

    return streak;
  }
}

/// 每日统计数据
class DailyStats {
  final DateTime date;
  final int studyMinutes;
  final int practicedSentences;
  final int dictationCorrect;
  final int dictationTotal;
  final double pronunciationScoreTotal;
  final int pronunciationCount;
  final int playCount;

  DailyStats({
    required this.date,
    required this.studyMinutes,
    required this.practicedSentences,
    required this.dictationCorrect,
    required this.dictationTotal,
    required this.pronunciationScoreTotal,
    required this.pronunciationCount,
    required this.playCount,
  });

  factory DailyStats.empty() => DailyStats(
    date: DateTime.now(),
    studyMinutes: 0,
    practicedSentences: 0,
    dictationCorrect: 0,
    dictationTotal: 0,
    pronunciationScoreTotal: 0,
    pronunciationCount: 0,
    playCount: 0,
  );

  bool get isToday {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  double get dictationAccuracy =>
    dictationTotal > 0 ? dictationCorrect / dictationTotal : 0;

  double get averagePronunciationScore =>
    pronunciationCount > 0 ? pronunciationScoreTotal / pronunciationCount : 0;

  DailyStats copyWith({
    DateTime? date,
    int? studyMinutes,
    int? practicedSentences,
    int? dictationCorrect,
    int? dictationTotal,
    double? pronunciationScoreTotal,
    int? pronunciationCount,
    int? playCount,
  }) {
    return DailyStats(
      date: date ?? this.date,
      studyMinutes: studyMinutes ?? this.studyMinutes,
      practicedSentences: practicedSentences ?? this.practicedSentences,
      dictationCorrect: dictationCorrect ?? this.dictationCorrect,
      dictationTotal: dictationTotal ?? this.dictationTotal,
      pronunciationScoreTotal: pronunciationScoreTotal ?? this.pronunciationScoreTotal,
      pronunciationCount: pronunciationCount ?? this.pronunciationCount,
      playCount: playCount ?? this.playCount,
    );
  }

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'studyMinutes': studyMinutes,
    'practicedSentences': practicedSentences,
    'dictationCorrect': dictationCorrect,
    'dictationTotal': dictationTotal,
    'pronunciationScoreTotal': pronunciationScoreTotal,
    'pronunciationCount': pronunciationCount,
    'playCount': playCount,
  };

  factory DailyStats.fromJson(Map<String, dynamic> json) {
    return DailyStats(
      date: DateTime.parse(json['date'] ?? DateTime.now().toIso8601String()),
      studyMinutes: json['studyMinutes'] ?? 0,
      practicedSentences: json['practicedSentences'] ?? 0,
      dictationCorrect: json['dictationCorrect'] ?? 0,
      dictationTotal: json['dictationTotal'] ?? 0,
      pronunciationScoreTotal: (json['pronunciationScoreTotal'] ?? 0).toDouble(),
      pronunciationCount: json['pronunciationCount'] ?? 0,
      playCount: json['playCount'] ?? 0,
    );
  }
}

/// 总统计数据
class TotalStats {
  final int totalStudyMinutes;
  final int totalPracticedSentences;
  final int totalDictationCorrect;
  final int totalDictationTotal;
  final double totalPronunciationScore;
  final int totalPronunciationCount;
  final int totalPlayCount;
  final int totalDays;

  TotalStats({
    required this.totalStudyMinutes,
    required this.totalPracticedSentences,
    required this.totalDictationCorrect,
    required this.totalDictationTotal,
    required this.totalPronunciationScore,
    required this.totalPronunciationCount,
    required this.totalPlayCount,
    required this.totalDays,
  });

  factory TotalStats.empty() => TotalStats(
    totalStudyMinutes: 0,
    totalPracticedSentences: 0,
    totalDictationCorrect: 0,
    totalDictationTotal: 0,
    totalPronunciationScore: 0,
    totalPronunciationCount: 0,
    totalPlayCount: 0,
    totalDays: 0,
  );

  double get dictationAccuracy =>
    totalDictationTotal > 0 ? totalDictationCorrect / totalDictationTotal : 0;

  double get averagePronunciationScore =>
    totalPronunciationCount > 0 ? totalPronunciationScore / totalPronunciationCount : 0;

  TotalStats addDaily(DailyStats daily) {
    return TotalStats(
      totalStudyMinutes: totalStudyMinutes + daily.studyMinutes,
      totalPracticedSentences: totalPracticedSentences + daily.practicedSentences,
      totalDictationCorrect: totalDictationCorrect + daily.dictationCorrect,
      totalDictationTotal: totalDictationTotal + daily.dictationTotal,
      totalPronunciationScore: totalPronunciationScore + daily.pronunciationScoreTotal,
      totalPronunciationCount: totalPronunciationCount + daily.pronunciationCount,
      totalPlayCount: totalPlayCount + daily.playCount,
      totalDays: totalDays + 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'totalStudyMinutes': totalStudyMinutes,
    'totalPracticedSentences': totalPracticedSentences,
    'totalDictationCorrect': totalDictationCorrect,
    'totalDictationTotal': totalDictationTotal,
    'totalPronunciationScore': totalPronunciationScore,
    'totalPronunciationCount': totalPronunciationCount,
    'totalPlayCount': totalPlayCount,
    'totalDays': totalDays,
  };

  factory TotalStats.fromJson(Map<String, dynamic> json) {
    return TotalStats(
      totalStudyMinutes: json['totalStudyMinutes'] ?? 0,
      totalPracticedSentences: json['totalPracticedSentences'] ?? 0,
      totalDictationCorrect: json['totalDictationCorrect'] ?? 0,
      totalDictationTotal: json['totalDictationTotal'] ?? 0,
      totalPronunciationScore: (json['totalPronunciationScore'] ?? 0).toDouble(),
      totalPronunciationCount: json['totalPronunciationCount'] ?? 0,
      totalPlayCount: json['totalPlayCount'] ?? 0,
      totalDays: json['totalDays'] ?? 0,
    );
  }
}
