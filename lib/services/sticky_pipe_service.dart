import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';

/// 启动结果类，包含是否成功和错误信息
class StickyLaunchResult {
  final bool success;
  final String? errorMessage;
  final String? errorDetails;

  StickyLaunchResult({
    required this.success,
    this.errorMessage,
    this.errorDetails,
  });

  factory StickyLaunchResult.ok() => StickyLaunchResult(success: true);

  factory StickyLaunchResult.error(String message, {String? details}) =>
      StickyLaunchResult(success: false, errorMessage: message, errorDetails: details);
}

/// 便签exe查找结果
class _StickyExeFindResult {
  final String? path;
  final String? errorMessage;
  final List<String> searchedPaths;

  _StickyExeFindResult({this.path, this.errorMessage, this.searchedPaths = const []});

  factory _StickyExeFindResult.found(String path) => _StickyExeFindResult(path: path);

  factory _StickyExeFindResult.notFound(List<String> searchedPaths) => _StickyExeFindResult(
        path: null,
        errorMessage: '已搜索以下路径但未找到StickyOverlay.exe:\n${searchedPaths.map((p) => '  • $p').join('\n')}',
        searchedPaths: searchedPaths,
      );
}

/// Service for communicating with the Sticky Overlay via TCP Socket
class StickyPipeService {
  static const String host = '127.0.0.1';
  static const int port = 9529;

  static Socket? _socket;
  static bool _isConnected = false;
  static String? _lastError;

  /// 获取最后一次错误信息
  static String? get lastError => _lastError;

  /// 获取插件是否正在运行（检查实际进程）
  static bool get isRunning => _isConnected && _socket != null;

  /// 检查 StickyOverlay 进程是否在运行
  static Future<bool> checkProcessRunning() async {
    try {
      final result = await Process.run('tasklist', ['/FI', 'IMAGENAME eq StickyOverlay.exe', '/NH']);
      return result.stdout.toString().contains('StickyOverlay.exe');
    } catch (_) {
      return false;
    }
  }

  /// Connect to the sticky overlay
  static Future<bool> connect() async {
    if (_isConnected && _socket != null) return true;

    try {
      _socket = await Socket.connect(host, port, timeout: const Duration(seconds: 2));
      _isConnected = true;

      _socket!.listen(
        (data) {
          final response = utf8.decode(data);
          if (kDebugMode) {
            debugPrint('Sticky response: $response');
          }
        },
        onError: (e) {
          if (kDebugMode) {
            debugPrint('Sticky socket error: $e');
          }
          _isConnected = false;
          _socket = null;
        },
        onDone: () {
          if (kDebugMode) {
            debugPrint('Sticky socket closed');
          }
          _isConnected = false;
          _socket = null;
        },
      );

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('StickyPipeService connect error: $e');
      }
      _isConnected = false;
      return false;
    }
  }

  /// Disconnect from the overlay
  static Future<void> disconnect() async {
    if (_socket != null) {
      await _socket!.close();
      _socket = null;
      _isConnected = false;
    }
  }

  /// Send a command to the sticky overlay
  static Future<bool> sendCommand(Map<String, dynamic> command) async {
    try {
      if (!_isConnected) {
        final connected = await connect();
        if (!connected) return false;
      }

      final json = jsonEncode(command);
      _socket!.write('$json\n');
      await _socket!.flush();

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('StickyPipeService sendCommand error: $e');
      }
      _isConnected = false;
      _socket = null;
      return false;
    }
  }

  /// Start the sticky overlay
  /// Returns StickyLaunchResult with detailed error information
  static Future<StickyLaunchResult> launchStickyOverlay({
    List<Map<String, dynamic>>? stickers,
  }) async {
    // Find the sticky overlay executable
    final findResult = _findStickyExe();
    if (findResult.path == null) {
      _lastError = findResult.errorMessage;
      return StickyLaunchResult.error(
        '找不到便签插件程序',
        details: findResult.errorMessage,
      );
    }

    final exePath = findResult.path!;

    try {
      final exeDir = File(exePath).parent.path;
      await Process.start(exePath, [], mode: ProcessStartMode.detached, workingDirectory: exeDir);

      // Wait for it to start (increased wait time)
      await Future.delayed(const Duration(milliseconds: 3000));

      // Connect to it with retries
      bool connected = false;
      for (int i = 0; i < 3; i++) {
        connected = await connect();
        if (connected) break;
        await Future.delayed(const Duration(milliseconds: 1000));
      }

      if (!connected) {
        return StickyLaunchResult.error(
          '无法连接到便签插件',
          details: _lastError ?? '连接超时，请检查程序是否正常启动',
        );
      }

      // Load stickers if provided
      if (stickers != null && stickers.isNotEmpty) {
        await loadSpace(stickers);
      }

      _lastError = null;
      return StickyLaunchResult.ok();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to launch StickyOverlay: $e');
      }
      _lastError = '启动失败: $e';
      return StickyLaunchResult.error(
        '便签插件启动失败',
        details: e.toString(),
      );
    }
  }

  /// Add a sticker
  static Future<bool> addSticker({
    required String word,
    String phonetic = '',
    required String translation,
    double x = 100,
    double y = 100,
    int styleIndex = 0,
  }) async {
    return sendCommand({
      'cmd': 'ADD_STICKER',
      'sticker': {
        'word': word,
        'phonetic': phonetic,
        'translation': translation,
        'x': x,
        'y': y,
        'styleIndex': styleIndex,
      },
    });
  }

  /// Load stickers for a space
  static Future<bool> loadSpace(List<Map<String, dynamic>> stickers) async {
    return sendCommand({
      'cmd': 'LOAD_SPACE',
      'stickers': stickers.map((s) => <String, dynamic>{
        'word': s['word'] ?? '',
        'phonetic': s['phonetic'] ?? '',
        'translation': s['translation'] ?? s['trans'] ?? '',
        'x': s['x'] ?? 100.0,
        'y': s['y'] ?? 100.0,
        'styleIndex': s['styleIndex'] ?? 0,
      }).toList(),
    });
  }

  /// Clear all stickers
  static Future<bool> clear() async {
    return sendCommand({'cmd': 'CLEAR'});
  }

  /// Stop the sticky overlay
  static Future<void> stop() async {
    // 先尝试发送STOP命令
    final sent = await sendCommand({'cmd': 'STOP'});
    
    if (sent) {
      // 等待overlay处理命令
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    await disconnect();
    
    // 如果发送失败或overlay没有关闭，直接结束进程
    try {
      final result = await Process.run('taskkill', ['/F', '/IM', 'StickyOverlay.exe']);
      if (kDebugMode && result.exitCode == 0) {
        debugPrint('StickyOverlay process terminated');
      }
    } catch (e) {
      // 进程可能已经不存在，忽略错误
    }
  }

  /// Check if overlay is running
  static bool get isConnected => _isConnected;

  /// Find the StickyOverlay.exe path
  static _StickyExeFindResult _findStickyExe() {
    final exeDir = File(Platform.resolvedExecutable).parent.path;

    // 获取项目根目录
    String projectDir = exeDir;
    if (exeDir.contains('build\\windows')) {
      projectDir = exeDir.replaceAll(RegExp(r'\\build\\windows.*$'), '');
    }

    // Possible locations (ordered by priority)
    final paths = [
      // Production paths (安装后的路径)
      '$exeDir\\plugins\\StickyOverlay.exe',
      '$exeDir\\StickyOverlay.exe',
      // installer_output 中已编译的插件 (开发调试时使用)
      '$projectDir\\installer_output\\extracted\\StickyOverlay.exe',
      // 项目内的 windows 子项目编译结果
      '$projectDir\\windows\\sticky_overlay\\bin\\Release\\net6.0-windows\\StickyOverlay.exe',
      '$projectDir\\windows\\sticky_overlay\\bin\\Debug\\net6.0-windows\\StickyOverlay.exe',
    ];

    if (kDebugMode) {
      debugPrint('Looking for StickyOverlay.exe...');
      debugPrint('Exe directory: $exeDir');
      debugPrint('Project directory: $projectDir');
    }

    for (final path in paths) {
      final file = File(path);
      if (file.existsSync()) {
        if (kDebugMode) {
          debugPrint('✅ Found StickyOverlay at: $path');
        }
        return _StickyExeFindResult.found(path);
      }
    }

    if (kDebugMode) {
      debugPrint('⚠️ StickyOverlay.exe not found');
    }
    return _StickyExeFindResult.notFound(paths);
  }
}
