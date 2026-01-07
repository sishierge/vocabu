import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 扩展插件设置服务 - 持久化所有插件配置
class ExtensionSettingsService {
  static final ExtensionSettingsService instance = ExtensionSettingsService._();
  ExtensionSettingsService._();

  SharedPreferences? _prefs;

  // === 键名常量 ===
  static const String _keyDanmuConfig = 'extension_danmu_config';
  static const String _keyCarouselConfig = 'extension_carousel_config';
  static const String _keyStickerConfig = 'extension_sticker_config';
  static const String _keyTtsConfig = 'extension_tts_config';

  /// 初始化（在 SettingsService 初始化时调用）
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ============ 插件启用状态 ============
  
  bool get isDanmuEnabled => _prefs?.getBool('danmu_enabled') ?? false;
  Future<void> setDanmuEnabled(bool enabled) async {
    await _prefs?.setBool('danmu_enabled', enabled);
  }

  bool get isCarouselEnabled => _prefs?.getBool('carousel_enabled') ?? false;
  Future<void> setCarouselEnabled(bool enabled) async {
    await _prefs?.setBool('carousel_enabled', enabled);
  }

  bool get isStickyEnabled => _prefs?.getBool('sticky_enabled') ?? false;
  Future<void> setStickyEnabled(bool enabled) async {
    await _prefs?.setBool('sticky_enabled', enabled);
  }

  // ============ 弹幕插件默认配置（人性化默认值） ============
  static const Map<String, dynamic> defaultDanmuConfig = {
    'areaTop': 5.0,           // 距顶部 5%（避免遮挡任务栏）
    'areaHeight': 60.0,       // 区域高度 60%（不占满屏幕）
    'speed': 0.6,             // 较慢速度，便于阅读
    'fontSize': 20.0,         // 舒适的字体大小
    'spawnInterval': 5,       // 5秒一个弹幕（不会太密集）
    'showTranslation': true,  // 默认显示翻译
    'wordColor': 0xFFFFFFFF,  // 白色单词
    'transColor': 0xFFFFD700, // 金色翻译
    'bgColor': 0xFF5B6CFF,    // 紫蓝色背景
    'opacity': 0.85,          // 85% 透明度
    'examplePosition': 'bottom-center',
    'exampleOffsetY': 80.0,   // 距离底部适中
  };

  // ============ 轮播插件默认配置 ============
  static const Map<String, dynamic> defaultCarouselConfig = {
    'interval': 8,            // 8秒切换（足够阅读）
    'position': 'bottom-right',
    'styleIndex': 0,
  };

  // ============ 贴纸插件默认配置 ============
  static const Map<String, dynamic> defaultStickerConfig = {
    'stickerCount': 8,        // 8个贴纸
    'fontSize': 16.0,
    'opacity': 0.95,
    'layout': 'random',
    'spacing': 25.0,
    'styleIndex': 0,
  };

  // ============ 离线语音默认配置 ============
  static const Map<String, dynamic> defaultTtsConfig = {
    'rate': 0.5,              // 中等语速
    'pitch': 1.0,
    'selectedVoice': '',
  };

  // ============ 弹幕插件 ============
  
  Map<String, dynamic> getDanmuConfig() {
    final json = _prefs?.getString(_keyDanmuConfig);
    if (json == null) return Map.from(defaultDanmuConfig);
    try {
      return Map<String, dynamic>.from(jsonDecode(json));
    } catch (e) {
      return Map.from(defaultDanmuConfig);
    }
  }

  Future<void> saveDanmuConfig(Map<String, dynamic> config) async {
    await _prefs?.setString(_keyDanmuConfig, jsonEncode(config));
  }

  Future<void> resetDanmuConfig() async {
    await _prefs?.remove(_keyDanmuConfig);
  }

  // ============ 轮播插件 ============
  
  Map<String, dynamic> getCarouselConfig() {
    final json = _prefs?.getString(_keyCarouselConfig);
    if (json == null) return Map.from(defaultCarouselConfig);
    try {
      return Map<String, dynamic>.from(jsonDecode(json));
    } catch (e) {
      return Map.from(defaultCarouselConfig);
    }
  }

  Future<void> saveCarouselConfig(Map<String, dynamic> config) async {
    await _prefs?.setString(_keyCarouselConfig, jsonEncode(config));
  }

  Future<void> resetCarouselConfig() async {
    await _prefs?.remove(_keyCarouselConfig);
  }

  // ============ 贴纸插件 ============
  
  Map<String, dynamic> getStickerConfig() {
    final json = _prefs?.getString(_keyStickerConfig);
    if (json == null) return Map.from(defaultStickerConfig);
    try {
      return Map<String, dynamic>.from(jsonDecode(json));
    } catch (e) {
      return Map.from(defaultStickerConfig);
    }
  }

  Future<void> saveStickerConfig(Map<String, dynamic> config) async {
    await _prefs?.setString(_keyStickerConfig, jsonEncode(config));
  }

  Future<void> resetStickerConfig() async {
    await _prefs?.remove(_keyStickerConfig);
  }

  // ============ 离线语音 ============
  
  Map<String, dynamic> getTtsConfig() {
    final json = _prefs?.getString(_keyTtsConfig);
    if (json == null) return Map.from(defaultTtsConfig);
    try {
      return Map<String, dynamic>.from(jsonDecode(json));
    } catch (e) {
      return Map.from(defaultTtsConfig);
    }
  }

  Future<void> saveTtsConfig(Map<String, dynamic> config) async {
    await _prefs?.setString(_keyTtsConfig, jsonEncode(config));
  }

  Future<void> resetTtsConfig() async {
    await _prefs?.remove(_keyTtsConfig);
  }
}
