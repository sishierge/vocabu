import 'dart:async';
import 'package:flutter/foundation.dart';
import '../providers/word_book_provider.dart';
import 'settings_service.dart';

/// 复习提醒服务 - 定期检查需要复习的单词并发出提醒
class ReviewReminderService extends ChangeNotifier {
  static final ReviewReminderService instance = ReviewReminderService._();
  ReviewReminderService._();

  Timer? _checkTimer;
  int _pendingReviewCount = 0;
  bool _hasNewReminder = false;
  DateTime? _lastReminderTime;

  // === 键名 ===
  static const String _keyReminderEnabled = 'reminder_enabled';
  static const String _keyReminderIntervalMinutes = 'reminder_interval_minutes';
  static const String _keyQuietHoursEnabled = 'quiet_hours_enabled';
  static const String _keyQuietHoursStart = 'quiet_hours_start'; // 格式: "22:00"
  static const String _keyQuietHoursEnd = 'quiet_hours_end'; // 格式: "08:00"

  /// 获取待复习单词数量
  int get pendingReviewCount => _pendingReviewCount;

  /// 是否有新提醒
  bool get hasNewReminder => _hasNewReminder;

  /// 清除新提醒标记
  void clearReminder() {
    _hasNewReminder = false;
    notifyListeners();
  }

  // ============ 设置 ============

  /// 是否启用提醒
  bool get reminderEnabled {
    return SettingsService.instance.getBool(_keyReminderEnabled, defaultValue: true);
  }

  Future<void> setReminderEnabled(bool value) async {
    await SettingsService.instance.setBool(_keyReminderEnabled, value);
    if (value) {
      startReminder();
    } else {
      stopReminder();
    }
    notifyListeners();
  }

  /// 提醒间隔（分钟）
  int get reminderIntervalMinutes {
    return SettingsService.instance.getInt(_keyReminderIntervalMinutes, defaultValue: 30);
  }

  Future<void> setReminderIntervalMinutes(int value) async {
    await SettingsService.instance.setInt(_keyReminderIntervalMinutes, value.clamp(5, 240));
    // 重启定时器
    if (reminderEnabled) {
      stopReminder();
      startReminder();
    }
    notifyListeners();
  }

  /// 是否启用免打扰时段
  bool get quietHoursEnabled {
    return SettingsService.instance.getBool(_keyQuietHoursEnabled, defaultValue: true);
  }

  Future<void> setQuietHoursEnabled(bool value) async {
    await SettingsService.instance.setBool(_keyQuietHoursEnabled, value);
    notifyListeners();
  }

  /// 免打扰开始时间
  String get quietHoursStart {
    return SettingsService.instance.getString(_keyQuietHoursStart, defaultValue: '22:00');
  }

  Future<void> setQuietHoursStart(String value) async {
    await SettingsService.instance.setString(_keyQuietHoursStart, value);
    notifyListeners();
  }

  /// 免打扰结束时间
  String get quietHoursEnd {
    return SettingsService.instance.getString(_keyQuietHoursEnd, defaultValue: '08:00');
  }

  Future<void> setQuietHoursEnd(String value) async {
    await SettingsService.instance.setString(_keyQuietHoursEnd, value);
    notifyListeners();
  }

  // ============ 核心功能 ============

  /// 启动提醒服务
  void startReminder() {
    if (!reminderEnabled) return;

    _checkTimer?.cancel();

    // 立即检查一次
    _checkPendingReviews();

    // 定期检查
    _checkTimer = Timer.periodic(
      Duration(minutes: reminderIntervalMinutes),
      (_) => _checkPendingReviews(),
    );

    if (kDebugMode) {
      debugPrint('ReviewReminderService started, interval: $reminderIntervalMinutes minutes');
    }
  }

  /// 停止提醒服务
  void stopReminder() {
    _checkTimer?.cancel();
    _checkTimer = null;
    if (kDebugMode) {
      debugPrint('ReviewReminderService stopped');
    }
  }

  /// 检查待复习单词
  Future<void> _checkPendingReviews() async {
    // 检查免打扰时段
    if (_isInQuietHours()) {
      if (kDebugMode) {
        debugPrint('In quiet hours, skipping reminder check');
      }
      return;
    }

    try {
      final provider = WordBookProvider.instance;
      final books = provider.books;

      int totalPending = 0;

      for (final book in books) {
        final reviewWords = await provider.getWordsForReview(book.bookId, limit: 1000);
        totalPending += reviewWords.length;
      }

      final previousCount = _pendingReviewCount;
      _pendingReviewCount = totalPending;

      // 如果有新的待复习单词，发出提醒
      if (totalPending > 0 && totalPending > previousCount) {
        _hasNewReminder = true;
        _lastReminderTime = DateTime.now();
        if (kDebugMode) {
          debugPrint('New review reminder: $totalPending words pending');
        }
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error checking pending reviews: $e');
      }
    }
  }

  /// 检查当前是否在免打扰时段
  bool _isInQuietHours() {
    if (!quietHoursEnabled) return false;

    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    final startParts = quietHoursStart.split(':');
    final startMinutes = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);

    final endParts = quietHoursEnd.split(':');
    final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);

    // 处理跨午夜的情况（如 22:00 - 08:00）
    if (startMinutes > endMinutes) {
      // 跨午夜
      return currentMinutes >= startMinutes || currentMinutes < endMinutes;
    } else {
      // 同一天
      return currentMinutes >= startMinutes && currentMinutes < endMinutes;
    }
  }

  /// 立即检查（手动刷新）
  Future<void> checkNow() async {
    await _checkPendingReviews();
  }

  /// 获取上次提醒时间
  DateTime? get lastReminderTime => _lastReminderTime;

  /// 获取提醒消息
  String get reminderMessage {
    if (_pendingReviewCount == 0) {
      return '暂无待复习单词';
    } else if (_pendingReviewCount < 10) {
      return '有 $_pendingReviewCount 个单词等待复习';
    } else if (_pendingReviewCount < 50) {
      return '有 $_pendingReviewCount 个单词需要复习，抓紧时间！';
    } else {
      return '有 $_pendingReviewCount 个单词堆积，建议立即复习！';
    }
  }

  @override
  void dispose() {
    stopReminder();
    super.dispose();
  }
}
