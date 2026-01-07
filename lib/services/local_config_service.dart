import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 用户偏好配置服务
class LocalConfigService {
  static LocalConfigService? _instance;
  static LocalConfigService get instance {
    _instance ??= LocalConfigService();
    return _instance!;
  }

  Map<String, dynamic> _config = {};
  String? _configPath;

  // 默认配置
  static const Map<String, dynamic> _defaultConfig = {
    'dailyNewWords': 20,        // 每日新学单词数
    'dailyReviewWords': 50,     // 每日复习单词数
    'autoPlayAudio': true,      // 自动播放发音
    'ttsSpeed': 0.5,            // TTS 语速 (0.0-1.0)
    'ttsVolume': 1.0,           // TTS 音量 (0.0-1.0)
    'showPhonetic': true,       // 显示音标
    'enableHotkeys': true,      // 启用快捷键
    'themeColor': '#3C8CE7',    // 主题色
    'fontFamily': 'Microsoft YaHei', // 字体
  };

  /// 获取配置值
  T get<T>(String key, {T? defaultValue}) {
    if (_config.containsKey(key)) {
      return _config[key] as T;
    }
    if (_defaultConfig.containsKey(key)) {
      return _defaultConfig[key] as T;
    }
    return defaultValue as T;
  }

  /// 设置配置值
  Future<void> set(String key, dynamic value) async {
    _config[key] = value;
    await _saveConfig();
  }

  /// 初始化配置
  Future<void> initialize() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _configPath = p.join(dir.path, 'LovingWord', 'localConfig.json');
      
      final file = File(_configPath!);
      if (await file.exists()) {
        final content = await file.readAsString();
        _config = json.decode(content) as Map<String, dynamic>;
        if (kDebugMode) {
          debugPrint('Config loaded: $_configPath');
        }
      } else {
        // 使用默认配置
        _config = Map.from(_defaultConfig);
        await _saveConfig();
        if (kDebugMode) {
          debugPrint('Config created with defaults: $_configPath');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading config: $e');
      }
      _config = Map.from(_defaultConfig);
    }
  }

  /// 保存配置到文件
  Future<void> _saveConfig() async {
    if (_configPath == null) return;
    
    try {
      final file = File(_configPath!);
      final dir = file.parent;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      await file.writeAsString(json.encode(_config));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error saving config: $e');
      }
    }
  }

  /// 重置为默认配置
  Future<void> reset() async {
    _config = Map.from(_defaultConfig);
    await _saveConfig();
  }

  // 便捷属性
  int get dailyNewWords => get<int>('dailyNewWords', defaultValue: 20);
  int get dailyReviewWords => get<int>('dailyReviewWords', defaultValue: 50);
  bool get autoPlayAudio => get<bool>('autoPlayAudio', defaultValue: true);
  double get ttsSpeed => get<num>('ttsSpeed', defaultValue: 0.5).toDouble();
  double get ttsVolume => get<num>('ttsVolume', defaultValue: 1.0).toDouble();
  bool get showPhonetic => get<bool>('showPhonetic', defaultValue: true);
}
