import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Service for communicating with the Carousel Overlay via TCP Socket
class CarouselPipeService {
  static const String host = '127.0.0.1';
  static const int port = 9528;

  static Socket? _socket;
  static bool _isConnected = false;

  /// 获取插件是否正在运行
  static bool get isRunning => _isConnected && _socket != null;

  /// 检查 CarouselOverlay 进程是否在运行
  static Future<bool> checkProcessRunning() async {
    try {
      final result = await Process.run('tasklist', ['/FI', 'IMAGENAME eq CarouselOverlay.exe', '/NH']);
      return result.stdout.toString().contains('CarouselOverlay.exe');
    } catch (_) {
      return false;
    }
  }

  /// Connect to the carousel overlay
  static Future<bool> connect() async {
    if (_isConnected && _socket != null) return true;

    try {
      _socket = await Socket.connect(host, port, timeout: const Duration(seconds: 2));
      _isConnected = true;

      _socket!.listen(
        (data) {
          final response = utf8.decode(data);
          if (kDebugMode) {
            debugPrint('Carousel response: $response');
          }
        },
        onError: (e) {
          if (kDebugMode) {
            debugPrint('Carousel socket error: $e');
          }
          _isConnected = false;
          _socket = null;
        },
        onDone: () {
          if (kDebugMode) {
            debugPrint('Carousel socket closed');
          }
          _isConnected = false;
          _socket = null;
        },
      );

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('CarouselPipeService connect error: $e');
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

  /// Send a command to the carousel overlay
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
        debugPrint('CarouselPipeService sendCommand error: $e');
      }
      _isConnected = false;
      _socket = null;
      return false;
    }
  }

  /// Start the carousel overlay with words and config
  static Future<bool> launchCarouselOverlay({
    required List<Map<String, dynamic>> words,
    int interval = 5,
    String position = 'bottom-right',
    int styleIndex = 0,
  }) async {
    final exePath = _findCarouselExe();
    if (exePath == null) {
      if (kDebugMode) {
        debugPrint('CarouselOverlay.exe not found');
      }
      return false;
    }

    try {
      final exeDir = File(exePath).parent.path;
      await Process.start(exePath, [], mode: ProcessStartMode.detached, workingDirectory: exeDir);

      // Wait for it to start and listen on TCP (increased wait time)
      await Future.delayed(const Duration(milliseconds: 3000));

      // Connect to it with retries
      bool connected = false;
      for (int i = 0; i < 3; i++) {
        connected = await connect();
        if (connected) break;
        await Future.delayed(const Duration(milliseconds: 1000));
      }

      if (!connected) {
        if (kDebugMode) {
          debugPrint('Failed to connect to CarouselOverlay');
        }
        return false;
      }

      // Send config
      await sendCommand({
        'cmd': 'CONFIG',
        'config': {
          'interval': interval,
          'position': position,
          'styleIndex': styleIndex,
        },
      });

      // Send words
      await sendCommand({
        'cmd': 'WORDS',
        'words': words.map((w) => <String, dynamic>{
          'Word': w['Word'] ?? w['word'] ?? '',
          'Phonetic': w['SymbolUs'] ?? w['Phonetic'] ?? w['phonetic'] ?? '',
          'Translation': w['Translate'] ?? w['Translation'] ?? w['trans'] ?? '',
        }).toList(),
      });

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to launch CarouselOverlay: $e');
      }
      return false;
    }
  }

  /// Update words in running overlay
  static Future<bool> updateWords(List<Map<String, dynamic>> words) async {
    return sendCommand({
      'cmd': 'WORDS',
      'words': words.map((w) => <String, dynamic>{
        'Word': w['Word'] ?? w['word'] ?? '',
        'Phonetic': w['SymbolUs'] ?? w['Phonetic'] ?? w['phonetic'] ?? '',
        'Translation': w['Translate'] ?? w['Translation'] ?? w['trans'] ?? '',
      }).toList(),
    });
  }

  /// Update config in running overlay
  static Future<bool> updateConfig({
    int? interval,
    String? position,
    int? styleIndex,
  }) async {
    final config = <String, dynamic>{};
    if (interval != null) config['interval'] = interval;
    if (position != null) config['position'] = position;
    if (styleIndex != null) config['styleIndex'] = styleIndex;

    return sendCommand({
      'cmd': 'CONFIG',
      'config': config,
    });
  }

  /// Stop the carousel overlay
  static Future<void> stop() async {
    final sent = await sendCommand({'cmd': 'STOP'});
    if (sent) {
      await Future.delayed(const Duration(milliseconds: 500));
    }
    await disconnect();
    
    // Fallback: kill process directly
    try {
      await Process.run('taskkill', ['/F', '/IM', 'CarouselOverlay.exe']);
    } catch (_) {}
  }

  /// Pause the carousel
  static Future<bool> pause() async {
    return sendCommand({'cmd': 'PAUSE'});
  }

  /// Resume the carousel
  static Future<bool> resume() async {
    return sendCommand({'cmd': 'RESUME'});
  }

  /// Next word
  static Future<bool> next() async {
    return sendCommand({'cmd': 'NEXT'});
  }

  /// Previous word
  static Future<bool> prev() async {
    return sendCommand({'cmd': 'PREV'});
  }

  /// Check if overlay is running
  static bool get isConnected => _isConnected;

  /// Find the CarouselOverlay.exe path
  static String? _findCarouselExe() {
    final exeDir = File(Platform.resolvedExecutable).parent.path;

    // 获取项目根目录
    String projectDir = exeDir;
    if (exeDir.contains('build\\windows')) {
      projectDir = exeDir.replaceAll(RegExp(r'\\build\\windows.*$'), '');
    }

    // Possible locations (ordered by priority)
    final paths = [
      // Production paths (安装后的路径)
      '$exeDir\\plugins\\CarouselOverlay.exe',
      '$exeDir\\CarouselOverlay.exe',
      // installer_output 中已编译的插件 (开发调试时使用)
      '$projectDir\\installer_output\\extracted\\CarouselOverlay.exe',
      // 项目内的 windows 子项目编译结果
      '$projectDir\\windows\\carousel_overlay\\bin\\Release\\net6.0-windows\\CarouselOverlay.exe',
      '$projectDir\\windows\\carousel_overlay\\bin\\Debug\\net6.0-windows\\CarouselOverlay.exe',
    ];

    for (final path in paths) {
      final file = File(path);
      if (file.existsSync()) {
        if (kDebugMode) {
          debugPrint('Found CarouselOverlay at: $path');
        }
        return path;
      }
    }

    if (kDebugMode) {
      debugPrint('CarouselOverlay.exe not found in any location');
    }
    return null;
  }
}
