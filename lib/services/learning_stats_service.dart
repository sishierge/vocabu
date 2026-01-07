import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 学习统计服务 - 追踪每日学习数据、连续打卡、成就等
class LearningStatsService {
  static final LearningStatsService instance = LearningStatsService._();
  LearningStatsService._();

  SharedPreferences? _prefs;

  // === 键名 ===
  static const String _keyDailyGoalNew = 'stats_daily_goal_new';
  static const String _keyDailyGoalReview = 'stats_daily_goal_review';
  static const String _keyTodayNewCount = 'stats_today_new_count';
  static const String _keyTodayReviewCount = 'stats_today_review_count';
  static const String _keyLastStudyDate = 'stats_last_study_date';
  static const String _keyCurrentStreak = 'stats_current_streak';
  static const String _keyLongestStreak = 'stats_longest_streak';
  static const String _keyTotalDaysStudied = 'stats_total_days_studied';
  static const String _keyTotalWordsLearned = 'stats_total_words_learned';
  static const String _keyTotalReviews = 'stats_total_reviews';
  static const String _keyAchievements = 'stats_achievements';
  static const String _keyDailyHistory = 'stats_daily_history';

  /// 初始化
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _checkDayChange();
  }

  // ============ 每日目标 ============

  /// 获取每日新词目标
  int get dailyGoalNew => _prefs?.getInt(_keyDailyGoalNew) ?? 20;

  /// 设置每日新词目标
  Future<void> setDailyGoalNew(int value) async {
    await _prefs?.setInt(_keyDailyGoalNew, value.clamp(5, 200));
  }

  /// 获取每日复习目标
  int get dailyGoalReview => _prefs?.getInt(_keyDailyGoalReview) ?? 50;

  /// 设置每日复习目标
  Future<void> setDailyGoalReview(int value) async {
    await _prefs?.setInt(_keyDailyGoalReview, value.clamp(10, 500));
  }

  // ============ 今日进度 ============

  /// 今日新学单词数
  int get todayNewCount => _prefs?.getInt(_keyTodayNewCount) ?? 0;

  /// 今日复习单词数
  int get todayReviewCount => _prefs?.getInt(_keyTodayReviewCount) ?? 0;

  /// 今日新词进度百分比
  double get todayNewProgress => (todayNewCount / dailyGoalNew).clamp(0.0, 1.0);

  /// 今日复习进度百分比
  double get todayReviewProgress => (todayReviewCount / dailyGoalReview).clamp(0.0, 1.0);

  /// 今日是否完成目标
  bool get todayGoalCompleted => todayNewCount >= dailyGoalNew && todayReviewCount >= dailyGoalReview;

  /// 记录学习新词
  Future<void> recordNewWord({int count = 1}) async {
    await _checkDayChange();
    final newCount = todayNewCount + count;
    await _prefs?.setInt(_keyTodayNewCount, newCount);
    await _prefs?.setInt(_keyTotalWordsLearned, totalWordsLearned + count);
    await _updateStreak();
    await _checkAchievements();
  }

  /// 记录复习单词
  Future<void> recordReview({int count = 1}) async {
    await _checkDayChange();
    final newCount = todayReviewCount + count;
    await _prefs?.setInt(_keyTodayReviewCount, newCount);
    await _prefs?.setInt(_keyTotalReviews, totalReviews + count);
    await _updateStreak();
    await _checkAchievements();
  }

  // ============ 连续打卡 ============

  /// 当前连续天数
  int get currentStreak => _prefs?.getInt(_keyCurrentStreak) ?? 0;

  /// 最长连续天数
  int get longestStreak => _prefs?.getInt(_keyLongestStreak) ?? 0;

  /// 总学习天数
  int get totalDaysStudied => _prefs?.getInt(_keyTotalDaysStudied) ?? 0;

  /// 总学习单词数
  int get totalWordsLearned => _prefs?.getInt(_keyTotalWordsLearned) ?? 0;

  /// 总复习次数
  int get totalReviews => _prefs?.getInt(_keyTotalReviews) ?? 0;

  /// 上次学习日期
  String? get lastStudyDate => _prefs?.getString(_keyLastStudyDate);

  /// 检查日期变化，重置每日计数
  Future<void> _checkDayChange() async {
    final today = _getTodayString();
    final lastDate = lastStudyDate;

    if (lastDate != today) {
      // 新的一天，重置计数
      await _prefs?.setInt(_keyTodayNewCount, 0);
      await _prefs?.setInt(_keyTodayReviewCount, 0);

      // 检查是否断签
      if (lastDate != null) {
        final lastDateTime = DateTime.parse(lastDate);
        final todayDateTime = DateTime.parse(today);
        final diff = todayDateTime.difference(lastDateTime).inDays;

        if (diff > 1) {
          // 断签了，重置连续天数
          await _prefs?.setInt(_keyCurrentStreak, 0);
          if (kDebugMode) {
            debugPrint('连续打卡中断，已重置');
          }
        }
      }
    }
  }

  /// 更新连续打卡
  Future<void> _updateStreak() async {
    final today = _getTodayString();
    final lastDate = lastStudyDate;

    if (lastDate != today) {
      // 今天第一次学习
      await _prefs?.setString(_keyLastStudyDate, today);
      await _prefs?.setInt(_keyTotalDaysStudied, totalDaysStudied + 1);

      final newStreak = currentStreak + 1;
      await _prefs?.setInt(_keyCurrentStreak, newStreak);

      if (newStreak > longestStreak) {
        await _prefs?.setInt(_keyLongestStreak, newStreak);
      }

      // 保存历史记录
      await _saveDailyHistory(today);

      if (kDebugMode) {
        debugPrint('✅ 打卡成功！连续 $newStreak 天');
      }
    }
  }

  // ============ 成就系统 ============

  /// 获取已解锁成就
  List<String> get unlockedAchievements {
    final json = _prefs?.getString(_keyAchievements);
    if (json == null) return [];
    try {
      return List<String>.from(jsonDecode(json));
    } catch (e) {
      return [];
    }
  }

  /// 检查并解锁成就
  Future<List<Achievement>> _checkAchievements() async {
    final unlocked = <Achievement>[];
    final current = unlockedAchievements;

    for (final achievement in allAchievements) {
      if (!current.contains(achievement.id) && achievement.checkCondition(this)) {
        current.add(achievement.id);
        unlocked.add(achievement);
        if (kDebugMode) {
          debugPrint('🏆 解锁成就: ${achievement.name}');
        }
      }
    }

    if (unlocked.isNotEmpty) {
      await _prefs?.setString(_keyAchievements, jsonEncode(current));
    }

    return unlocked;
  }

  /// 获取所有成就及状态
  List<AchievementStatus> getAchievementStatuses() {
    final unlocked = unlockedAchievements;
    return allAchievements.map((a) => AchievementStatus(
      achievement: a,
      isUnlocked: unlocked.contains(a.id),
    )).toList();
  }

  // ============ 历史记录 ============

  /// 获取学习历史（热力图数据）
  Map<String, int> getDailyHistory() {
    final json = _prefs?.getString(_keyDailyHistory);
    if (json == null) return {};
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, v as int));
    } catch (e) {
      return {};
    }
  }

  /// 保存当日历史
  Future<void> _saveDailyHistory(String date) async {
    final history = getDailyHistory();
    history[date] = todayNewCount + todayReviewCount;
    await _prefs?.setString(_keyDailyHistory, jsonEncode(history));
  }

  /// 获取今天的日期字符串
  String _getTodayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  // ============ 统计摘要 ============

  /// 获取统计摘要
  LearningStatsSummary getSummary() {
    return LearningStatsSummary(
      todayNew: todayNewCount,
      todayReview: todayReviewCount,
      dailyGoalNew: dailyGoalNew,
      dailyGoalReview: dailyGoalReview,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      totalDays: totalDaysStudied,
      totalWords: totalWordsLearned,
      totalReviews: totalReviews,
    );
  }
}

/// 学习统计摘要
class LearningStatsSummary {
  final int todayNew;
  final int todayReview;
  final int dailyGoalNew;
  final int dailyGoalReview;
  final int currentStreak;
  final int longestStreak;
  final int totalDays;
  final int totalWords;
  final int totalReviews;

  LearningStatsSummary({
    required this.todayNew,
    required this.todayReview,
    required this.dailyGoalNew,
    required this.dailyGoalReview,
    required this.currentStreak,
    required this.longestStreak,
    required this.totalDays,
    required this.totalWords,
    required this.totalReviews,
  });

  double get newProgress => (todayNew / dailyGoalNew).clamp(0.0, 1.0);
  double get reviewProgress => (todayReview / dailyGoalReview).clamp(0.0, 1.0);
  bool get goalCompleted => todayNew >= dailyGoalNew && todayReview >= dailyGoalReview;
}

/// 成就定义
class Achievement {
  final String id;
  final String name;
  final String description;
  final String icon;
  final bool Function(LearningStatsService stats) checkCondition;

  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.checkCondition,
  });
}

/// 成就状态
class AchievementStatus {
  final Achievement achievement;
  final bool isUnlocked;

  AchievementStatus({required this.achievement, required this.isUnlocked});
}

/// 所有成就列表
final List<Achievement> allAchievements = [
  // 打卡成就
  Achievement(
    id: 'streak_3',
    name: '初露锋芒',
    description: '连续学习3天',
    icon: '🌱',
    checkCondition: (s) => s.currentStreak >= 3,
  ),
  Achievement(
    id: 'streak_7',
    name: '坚持一周',
    description: '连续学习7天',
    icon: '🌿',
    checkCondition: (s) => s.currentStreak >= 7,
  ),
  Achievement(
    id: 'streak_30',
    name: '习惯养成',
    description: '连续学习30天',
    icon: '🌳',
    checkCondition: (s) => s.currentStreak >= 30,
  ),
  Achievement(
    id: 'streak_100',
    name: '百日坚持',
    description: '连续学习100天',
    icon: '🏆',
    checkCondition: (s) => s.currentStreak >= 100,
  ),
  Achievement(
    id: 'streak_365',
    name: '全年无休',
    description: '连续学习365天',
    icon: '👑',
    checkCondition: (s) => s.currentStreak >= 365,
  ),

  // 单词量成就
  Achievement(
    id: 'words_100',
    name: '词汇新手',
    description: '累计学习100个单词',
    icon: '📚',
    checkCondition: (s) => s.totalWordsLearned >= 100,
  ),
  Achievement(
    id: 'words_500',
    name: '词汇达人',
    description: '累计学习500个单词',
    icon: '📖',
    checkCondition: (s) => s.totalWordsLearned >= 500,
  ),
  Achievement(
    id: 'words_1000',
    name: '词汇专家',
    description: '累计学习1000个单词',
    icon: '🎓',
    checkCondition: (s) => s.totalWordsLearned >= 1000,
  ),
  Achievement(
    id: 'words_5000',
    name: '词汇大师',
    description: '累计学习5000个单词',
    icon: '🎯',
    checkCondition: (s) => s.totalWordsLearned >= 5000,
  ),

  // 复习成就
  Achievement(
    id: 'reviews_500',
    name: '复习新手',
    description: '累计复习500次',
    icon: '🔄',
    checkCondition: (s) => s.totalReviews >= 500,
  ),
  Achievement(
    id: 'reviews_5000',
    name: '复习达人',
    description: '累计复习5000次',
    icon: '💪',
    checkCondition: (s) => s.totalReviews >= 5000,
  ),

  // 特殊成就
  Achievement(
    id: 'first_goal',
    name: '首次达标',
    description: '首次完成每日目标',
    icon: '⭐',
    checkCondition: (s) => s.todayGoalCompleted,
  ),
];
