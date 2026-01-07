import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'danmu_pipe_service.dart';
import 'sticky_pipe_service.dart';
import 'extension_settings_service.dart';
import '../providers/word_book_provider.dart';

/// 插件运行状态
enum PluginStatus { stopped, running }

/// 系统托盘服务 - 管理 Windows 系统托盘图标
class SystemTrayService with TrayListener {
  static final SystemTrayService instance = SystemTrayService._();
  SystemTrayService._();

  bool _isInitialized = false;
  PluginStatus _danmuStatus = PluginStatus.stopped;
  PluginStatus _stickyStatus = PluginStatus.stopped;

  /// 获取弹幕插件状态
  PluginStatus get danmuStatus => _danmuStatus;

  /// 获取便签插件状态
  PluginStatus get stickyStatus => _stickyStatus;

  /// 初始化系统托盘
  Future<void> initialize() async {
    if (_isInitialized || !Platform.isWindows) return;

    try {
      // 获取图标路径 - 使用 Windows 资源目录中的图标
      final exePath = Platform.resolvedExecutable;
      final exeDir = p.dirname(exePath);
      final iconPath = p.join(exeDir, 'data', 'flutter_assets', 'assets', 'images', 'app_icon.ico');

      // 备选路径：直接在资源目录
      final altIconPath = p.join(exeDir, 'app_icon.ico');

      // 检查哪个路径存在
      String finalIconPath = iconPath;
      if (!File(iconPath).existsSync()) {
        if (File(altIconPath).existsSync()) {
          finalIconPath = altIconPath;
        } else {
          // 开发模式下使用相对路径
          finalIconPath = 'windows/runner/resources/app_icon.ico';
        }
      }

      if (kDebugMode) {
        debugPrint('System tray icon path: $finalIconPath');
      }

      // 设置托盘图标
      await trayManager.setIcon(finalIconPath);

      // 设置托盘菜单
      final menu = Menu(
        items: [
          MenuItem(
            key: 'show',
            label: '显示主窗口',
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'start_danmu',
            label: '启动弹幕模式',
          ),
          MenuItem(
            key: 'start_sticky',
            label: '启动便签模式',
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'exit',
            label: '退出',
          ),
        ],
      );
      await trayManager.setContextMenu(menu);

      // 设置托盘提示文本
      await trayManager.setToolTip('Vocabu - 智能英语学习助手');

      // 添加监听器
      trayManager.addListener(this);

      _isInitialized = true;
      if (kDebugMode) {
        debugPrint('System tray initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to initialize system tray: $e');
      }
    }
  }

  /// 销毁系统托盘
  Future<void> destroy() async {
    if (!_isInitialized) return;

    trayManager.removeListener(this);
    await trayManager.destroy();
    _isInitialized = false;
  }

  /// 托盘图标点击事件
  @override
  void onTrayIconMouseDown() {
    _showWindow();
  }

  /// 托盘图标右键点击事件
  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  /// 托盘菜单项点击事件
  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        _showWindow();
        break;
      case 'start_danmu':
        _launchDanmuMode();
        break;
      case 'stop_danmu':
        _stopDanmuMode();
        break;
      case 'start_sticky':
        _launchStickyMode();
        break;
      case 'stop_sticky':
        _stopStickyMode();
        break;
      case 'exit':
        _exitApp();
        break;
    }
  }

  /// 启动弹幕模式
  Future<void> _launchDanmuMode() async {
    if (_danmuStatus == PluginStatus.running) {
      if (kDebugMode) {
        debugPrint('Danmu mode already running');
      }
      return;
    }

    try {
      // 获取配置
      final config = ExtensionSettingsService.instance.getDanmuConfig();

      // 获取单词（从第一个词书加载）
      final provider = WordBookProvider.instance;
      final books = provider.books;
      if (books.isEmpty) {
        if (kDebugMode) {
          debugPrint('No word books available for danmu mode');
        }
        return;
      }

      final words = await provider.getWordsForBook(books.first.bookId, limit: 100);
      if (words.isEmpty) {
        if (kDebugMode) {
          debugPrint('No words available for danmu mode');
        }
        return;
      }

      // 启动弹幕
      final result = await DanmuPipeService.launchDanmuOverlay(
        words: words,
        config: config,
      );

      if (result.success) {
        _danmuStatus = PluginStatus.running;
        await _updateMenu();
        if (kDebugMode) {
          debugPrint('Danmu mode started successfully');
        }
      } else {
        if (kDebugMode) {
          debugPrint('Failed to start danmu: ${result.errorMessage}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error launching danmu mode: $e');
      }
    }
  }

  /// 停止弹幕模式
  Future<void> _stopDanmuMode() async {
    if (_danmuStatus == PluginStatus.stopped) return;

    await DanmuPipeService.stop();
    _danmuStatus = PluginStatus.stopped;
    await _updateMenu();
    if (kDebugMode) {
      debugPrint('Danmu mode stopped');
    }
  }

  /// 启动便签模式
  Future<void> _launchStickyMode() async {
    if (_stickyStatus == PluginStatus.running) {
      if (kDebugMode) {
        debugPrint('Sticky mode already running');
      }
      return;
    }

    try {
      // 获取单词转换为便签格式
      final provider = WordBookProvider.instance;
      final books = provider.books;
      if (books.isEmpty) {
        if (kDebugMode) {
          debugPrint('No word books available for sticky mode');
        }
        return;
      }

      final words = await provider.getWordsForBook(books.first.bookId, limit: 20);
      final stickers = words.map((w) => {
        'word': w['Word'] ?? '',
        'phonetic': w['SymbolUs'] ?? w['SymbolEn'] ?? '',
        'translation': w['Translate'] ?? '',
        'x': 100.0 + (words.indexOf(w) % 5) * 200,
        'y': 100.0 + (words.indexOf(w) ~/ 5) * 150,
        'styleIndex': words.indexOf(w) % 4,
      }).toList();

      // 启动便签
      final result = await StickyPipeService.launchStickyOverlay(stickers: stickers);

      if (result.success) {
        _stickyStatus = PluginStatus.running;
        await _updateMenu();
        if (kDebugMode) {
          debugPrint('Sticky mode started successfully');
        }
      } else {
        if (kDebugMode) {
          debugPrint('Failed to start sticky: ${result.errorMessage}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error launching sticky mode: $e');
      }
    }
  }

  /// 停止便签模式
  Future<void> _stopStickyMode() async {
    if (_stickyStatus == PluginStatus.stopped) return;

    await StickyPipeService.stop();
    _stickyStatus = PluginStatus.stopped;
    await _updateMenu();
    if (kDebugMode) {
      debugPrint('Sticky mode stopped');
    }
  }

  /// 更新托盘菜单（根据运行状态）
  Future<void> _updateMenu() async {
    if (!_isInitialized) return;

    final menu = Menu(
      items: [
        MenuItem(
          key: 'show',
          label: '显示主窗口',
        ),
        MenuItem.separator(),
        // 弹幕模式菜单项
        if (_danmuStatus == PluginStatus.stopped)
          MenuItem(
            key: 'start_danmu',
            label: '启动弹幕模式',
          )
        else
          MenuItem(
            key: 'stop_danmu',
            label: '停止弹幕模式 ●',
          ),
        // 便签模式菜单项
        if (_stickyStatus == PluginStatus.stopped)
          MenuItem(
            key: 'start_sticky',
            label: '启动便签模式',
          )
        else
          MenuItem(
            key: 'stop_sticky',
            label: '停止便签模式 ●',
          ),
        MenuItem.separator(),
        MenuItem(
          key: 'exit',
          label: '退出',
        ),
      ],
    );
    await trayManager.setContextMenu(menu);
  }

  /// 显示主窗口
  void _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  /// 退出应用
  void _exitApp() async {
    await destroy();
    exit(0);
  }

  /// 更新托盘图标提示（如显示待复习数量）
  Future<void> updateToolTip(String message) async {
    if (!_isInitialized) return;
    await trayManager.setToolTip(message);
  }
}
