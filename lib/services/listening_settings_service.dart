import 'package:shared_preferences/shared_preferences.dart';

/// 听力设置服务
class ListeningSettingsService {
  static final ListeningSettingsService instance = ListeningSettingsService._();
  ListeningSettingsService._();

  static const String _keySpeechRate = 'listening_speech_rate';
  static const String _keyLoopMode = 'listening_loop_mode';
  static const String _keyAutoNext = 'listening_auto_next';
  static const String _keyAutoNextDelay = 'listening_auto_next_delay';
  static const String _keyShowEnglishByDefault = 'listening_show_english';
  static const String _keyShowChineseByDefault = 'listening_show_chinese';

  // 默认值
  double _speechRate = 0.5;
  bool _loopMode = false;
  bool _autoNext = false;
  int _autoNextDelay = 2; // 秒
  bool _showEnglishByDefault = false;
  bool _showChineseByDefault = false;
  bool _initialized = false;

  // Getters
  double get speechRate => _speechRate;
  bool get loopMode => _loopMode;
  bool get autoNext => _autoNext;
  int get autoNextDelay => _autoNextDelay;
  bool get showEnglishByDefault => _showEnglishByDefault;
  bool get showChineseByDefault => _showChineseByDefault;

  /// 初始化设置
  Future<void> initialize() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    _speechRate = prefs.getDouble(_keySpeechRate) ?? 0.5;
    _loopMode = prefs.getBool(_keyLoopMode) ?? false;
    _autoNext = prefs.getBool(_keyAutoNext) ?? false;
    _autoNextDelay = prefs.getInt(_keyAutoNextDelay) ?? 2;
    _showEnglishByDefault = prefs.getBool(_keyShowEnglishByDefault) ?? false;
    _showChineseByDefault = prefs.getBool(_keyShowChineseByDefault) ?? false;

    _initialized = true;
  }

  /// 设置语速 (0.2 - 1.0)
  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate.clamp(0.2, 1.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keySpeechRate, _speechRate);
  }

  /// 设置单句循环模式
  Future<void> setLoopMode(bool enabled) async {
    _loopMode = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLoopMode, enabled);
  }

  /// 设置自动下一句
  Future<void> setAutoNext(bool enabled) async {
    _autoNext = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoNext, enabled);
  }

  /// 设置自动下一句延迟（秒）
  Future<void> setAutoNextDelay(int seconds) async {
    _autoNextDelay = seconds.clamp(1, 10);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyAutoNextDelay, _autoNextDelay);
  }

  /// 设置默认显示英文
  Future<void> setShowEnglishByDefault(bool show) async {
    _showEnglishByDefault = show;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowEnglishByDefault, show);
  }

  /// 设置默认显示中文
  Future<void> setShowChineseByDefault(bool show) async {
    _showChineseByDefault = show;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowChineseByDefault, show);
  }
}
