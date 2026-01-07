import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 设置服务 - 管理所有设置项的持久化
class SettingsService {
  static final SettingsService instance = SettingsService._();
  SettingsService._();

  SharedPreferences? _prefs;

  // === 设置项键名 ===
  static const String _keyAutoStart = 'settings_auto_start';
  static const String _keyProcessMode = 'settings_process_mode';
  static const String _keyAlgorithm = 'settings_algorithm'; // 'fsrs' or 'stepmaster'
  static const String _keyQuickLinks = 'settings_quick_links';
  static const String _keyWebDavUrl = 'settings_webdav_url';
  static const String _keyWebDavUser = 'settings_webdav_user';
  static const String _keyWebDavPass = 'settings_webdav_pass';

  // === 默认快捷链接 ===
  static const List<Map<String, String>> defaultQuickLinks = [
    {'name': '百度翻译', 'url': 'https://fanyi.baidu.com/#en/zh/@word'},
    {'name': '海词词典', 'url': 'https://dict.cn/search?q=@word'},
    {'name': '金山词霸', 'url': 'http://www.iciba.com/word?w=@word'},
    {'name': '有道词典', 'url': 'https://dict.youdao.com/result?word=@word&lang=en'},
    {'name': 'etymonline词源', 'url': 'https://www.etymonline.com/word/@word'},
    {'name': '百度搜索', 'url': 'https://www.baidu.com/s?wd=@word'},
  ];

  /// 初始化
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ============ 通用 getter/setter ============

  /// 获取布尔值
  bool getBool(String key, {bool defaultValue = false}) {
    return _prefs?.getBool(key) ?? defaultValue;
  }

  /// 设置布尔值
  Future<void> setBool(String key, bool value) async {
    await _prefs?.setBool(key, value);
  }

  /// 获取整数值
  int getInt(String key, {int defaultValue = 0}) {
    return _prefs?.getInt(key) ?? defaultValue;
  }

  /// 设置整数值
  Future<void> setInt(String key, int value) async {
    await _prefs?.setInt(key, value);
  }

  /// 获取字符串值
  String getString(String key, {String defaultValue = ''}) {
    return _prefs?.getString(key) ?? defaultValue;
  }

  /// 设置字符串值
  Future<void> setString(String key, String value) async {
    await _prefs?.setString(key, value);
  }

  // ============ 基本设置 ============

  /// 获取开机自启状态
  bool get autoStart => _prefs?.getBool(_keyAutoStart) ?? false;

  /// 设置开机自启
  Future<void> setAutoStart(bool value) async {
    await _prefs?.setBool(_keyAutoStart, value);
    await _setWindowsAutoStart(value);
  }

  /// 获取子进程运行方式 (0=默认, 1=Explorer)
  int get processMode => _prefs?.getInt(_keyProcessMode) ?? 0;

  /// 设置子进程运行方式
  Future<void> setProcessMode(int value) async {
    await _prefs?.setInt(_keyProcessMode, value);
  }

  // ============ 记忆算法 ============

  /// 获取当前算法 ('fsrs' or 'stepmaster')
  String get algorithm => _prefs?.getString(_keyAlgorithm) ?? 'fsrs';

  /// 设置当前算法
  Future<void> setAlgorithm(String value) async {
    await _prefs?.setString(_keyAlgorithm, value);
  }

  // ============ 快捷链接 ============

  /// 获取快捷链接列表
  List<Map<String, String>> get quickLinks {
    final json = _prefs?.getString(_keyQuickLinks);
    if (json == null) return List.from(defaultQuickLinks);
    try {
      final list = jsonDecode(json) as List;
      return list.map((e) => Map<String, String>.from(e)).toList();
    } catch (e) {
      return List.from(defaultQuickLinks);
    }
  }

  /// 保存快捷链接列表
  Future<void> setQuickLinks(List<Map<String, String>> links) async {
    final json = jsonEncode(links);
    await _prefs?.setString(_keyQuickLinks, json);
  }

  /// 添加快捷链接
  Future<void> addQuickLink(String name, String url) async {
    final links = quickLinks;
    links.add({'name': name, 'url': url});
    await setQuickLinks(links);
  }

  /// 更新快捷链接
  Future<void> updateQuickLink(int index, String name, String url) async {
    final links = quickLinks;
    if (index >= 0 && index < links.length) {
      links[index] = {'name': name, 'url': url};
      await setQuickLinks(links);
    }
  }

  /// 删除快捷链接
  Future<void> deleteQuickLink(int index) async {
    final links = quickLinks;
    if (index >= 0 && index < links.length) {
      links.removeAt(index);
      await setQuickLinks(links);
    }
  }

  // ============ WebDAV 配置 ============

  /// 获取 WebDAV 配置
  Map<String, String> get webDavConfig => {
    'url': _prefs?.getString(_keyWebDavUrl) ?? '',
    'user': _prefs?.getString(_keyWebDavUser) ?? '',
    'pass': _prefs?.getString(_keyWebDavPass) ?? '',
  };

  /// 是否已配置 WebDAV
  bool get hasWebDavConfig => webDavConfig['url']?.isNotEmpty ?? false;

  /// 保存 WebDAV 配置
  Future<void> setWebDavConfig(String url, String user, String pass) async {
    await _prefs?.setString(_keyWebDavUrl, url);
    await _prefs?.setString(_keyWebDavUser, user);
    await _prefs?.setString(_keyWebDavPass, pass);
  }

  /// 清除 WebDAV 配置
  Future<void> clearWebDavConfig() async {
    await _prefs?.remove(_keyWebDavUrl);
    await _prefs?.remove(_keyWebDavUser);
    await _prefs?.remove(_keyWebDavPass);
  }

  // ============ Windows 开机自启 ============

  /// 设置 Windows 开机自启（注册表操作）
  Future<void> _setWindowsAutoStart(bool enable) async {
    if (!Platform.isWindows) return;

    try {
      final exePath = Platform.resolvedExecutable;
      const appName = 'LovingWord';

      if (enable) {
        // 添加到启动项
        await Process.run('reg', [
          'add',
          r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run',
          '/v', appName,
          '/t', 'REG_SZ',
          '/d', '"$exePath"',
          '/f'
        ]);
        if (kDebugMode) {
          debugPrint('✅ 开机自启已启用: $exePath');
        }
      } else {
        // 从启动项移除
        await Process.run('reg', [
          'delete',
          r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run',
          '/v', appName,
          '/f'
        ]);
        if (kDebugMode) {
          debugPrint('⛔ 开机自启已禁用');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 设置开机自启失败: $e');
      }
    }
  }
}
