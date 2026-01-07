import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../repositories/word_repository.dart';
import '../services/database_helper.dart';

/// Callback type for word mastered event
typedef WordMasteredCallback = void Function(String word);

/// 启动结果类，包含是否成功和错误信息
class DanmuLaunchResult {
  final bool success;
  final String? errorMessage;
  final String? errorDetails;

  DanmuLaunchResult({
    required this.success,
    this.errorMessage,
    this.errorDetails,
  });

  factory DanmuLaunchResult.ok() => DanmuLaunchResult(success: true);

  factory DanmuLaunchResult.error(String message, {String? details}) =>
      DanmuLaunchResult(success: false, errorMessage: message, errorDetails: details);
}

/// 弹幕exe查找结果
class _DanmuExeFindResult {
  final String? path;
  final String? errorMessage;
  final List<String> searchedPaths;

  _DanmuExeFindResult({this.path, this.errorMessage, this.searchedPaths = const []});

  factory _DanmuExeFindResult.found(String path) => _DanmuExeFindResult(path: path);

  factory _DanmuExeFindResult.notFound(List<String> searchedPaths) => _DanmuExeFindResult(
        path: null,
        errorMessage: '已搜索以下路径但未找到DanmuOverlay.exe:\n${searchedPaths.map((p) => '  • $p').join('\n')}',
        searchedPaths: searchedPaths,
      );
}

/// Service for communicating with the native Danmu Overlay via TCP Socket
class DanmuPipeService {
  static const String host = '127.0.0.1';
  static const int port = 9527;

  static Socket? _socket;
  static bool _isConnected = false;
  static String _receiveBuffer = '';
  static String? _lastError;

  /// 获取最后一次错误信息
  static String? get lastError => _lastError;

  /// 获取插件是否正在运行
  static bool get isRunning => _isConnected && _socket != null;

  /// 检查 DanmuOverlay 进程是否在运行
  static Future<bool> checkProcessRunning() async {
    try {
      final result = await Process.run('tasklist', ['/FI', 'IMAGENAME eq DanmuOverlay.exe', '/NH']);
      return result.stdout.toString().contains('DanmuOverlay.exe');
    } catch (_) {
      return false;
    }
  }

  /// Callback when word is marked as mastered from overlay
  static WordMasteredCallback? onWordMastered;

  /// Connect to the danmu overlay
  static Future<bool> connect() async {
    if (_isConnected && _socket != null) return true;

    try {
      _socket = await Socket.connect(host, port, timeout: const Duration(seconds: 2));
      _isConnected = true;
      _lastError = null;

      _socket!.listen(
        (data) {
          // Append to buffer and process complete messages
          _receiveBuffer += utf8.decode(data);
          _processReceivedData();
        },
        onError: (e) {
          if (kDebugMode) {
            debugPrint('Danmu socket error: $e');
          }
          _lastError = 'Socket错误: $e';
          _isConnected = false;
          _socket = null;
        },
        onDone: () {
          if (kDebugMode) {
            debugPrint('Danmu socket closed');
          }
          _isConnected = false;
          _socket = null;
        },
      );

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DanmuPipeService connect error: $e');
      }
      _lastError = '连接失败: $e';
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

  /// Send a command to the danmu overlay
  static Future<bool> sendCommand(Map<String, dynamic> command) async {
    try {
      // Try to connect if not connected
      if (!_isConnected) {
        final connected = await connect();
        if (!connected) return false;
      }

      // Send JSON command with newline delimiter
      final json = jsonEncode(command);
      _socket!.write('$json\n');
      await _socket!.flush();

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DanmuPipeService sendCommand error: $e');
      }
      _lastError = '发送命令失败: $e';
      _isConnected = false;
      _socket = null;
      return false;
    }
  }

  /// Start the danmu overlay with words and config
  /// Returns DanmuLaunchResult with detailed error information
  static Future<DanmuLaunchResult> launchDanmuOverlay({
    required List<Map<String, dynamic>> words,
    required Map<String, dynamic> config,
  }) async {
    // 先停止已有的进程，避免端口冲突
    try {
      await Process.run('taskkill', ['/F', '/IM', 'DanmuOverlay.exe']);
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (_) {}

    // Find the danmu overlay executable
    final findResult = _findDanmuExe();
    if (findResult.path == null) {
      _lastError = findResult.errorMessage;
      return DanmuLaunchResult.error(
        '找不到弹幕插件程序',
        details: findResult.errorMessage,
      );
    }

    final exePath = findResult.path!;

    // Launch the overlay process
    try {
      final exeDir = File(exePath).parent.path;
      if (kDebugMode) {
        debugPrint('Launching DanmuOverlay from: $exePath');
        debugPrint('Working directory: $exeDir');
      }

      await Process.start(exePath, [], mode: ProcessStartMode.detached, workingDirectory: exeDir);

      // Wait for it to start and listen on TCP
      await Future.delayed(const Duration(milliseconds: 2000));

      // Connect to it with retries
      bool connected = false;
      String? connectError;
      for (int i = 0; i < 5; i++) {
        if (kDebugMode) {
          debugPrint('Connection attempt ${i + 1}/5...');
        }
        connected = await connect();
        if (connected) {
          if (kDebugMode) {
            debugPrint('Connected successfully!');
          }
          break;
        }
        connectError = _lastError;
        await Future.delayed(const Duration(milliseconds: 800));
      }

      if (!connected) {
        return DanmuLaunchResult.error(
          '无法连接到弹幕插件',
          details: connectError ?? '连接超时，请检查程序是否正常启动',
        );
      }

      // 短暂等待确保连接稳定
      await Future.delayed(const Duration(milliseconds: 200));

      // Send full config
      if (kDebugMode) {
        debugPrint('弹幕: 发送CONFIG命令...');
      }
      final configSent = await sendCommand({
        'cmd': 'CONFIG',
        'config': config,
      });

      if (!configSent) {
        if (kDebugMode) {
          debugPrint('弹幕: CONFIG命令发送失败');
        }
      } else if (kDebugMode) {
        debugPrint('弹幕: CONFIG命令发送成功');
      }

      // Send words with example sentences
      if (kDebugMode) {
        debugPrint('弹幕: 发送WORDS命令，共${words.length}个单词...');
        // 显示前3个单词的示例数据
        for (int i = 0; i < 3 && i < words.length; i++) {
          final w = words[i];
          final ex = w['SentenceEn'] ?? w['Example'] ?? '';
          debugPrint('  示例[$i]: ${w['Word']} - 例句: ${ex.toString().length > 30 ? '${ex.toString().substring(0, 30)}...' : ex}');
        }
      }
      final wordsSent = await sendCommand({
        'cmd': 'WORDS',
        'words': words.map((w) => <String, dynamic>{
          'Word': w['Word'] ?? w['word'] ?? '',
          'Translation': w['Translate'] ?? w['Translation'] ?? w['trans'] ?? '',
          'Example': w['SentenceEn'] ?? w['Example'] ?? w['example'] ?? '',
          'ExampleTrans': w['SentenceCn'] ?? w['ExampleTrans'] ?? w['exampleTrans'] ?? '',
        }).toList(),
      });

      if (!wordsSent) {
        if (kDebugMode) {
          debugPrint('弹幕: WORDS命令发送失败');
        }
      } else if (kDebugMode) {
        debugPrint('弹幕: WORDS命令发送成功');
      }

      _lastError = null;
      return DanmuLaunchResult.ok();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to launch DanmuOverlay: $e');
      }
      _lastError = '启动失败: $e';
      return DanmuLaunchResult.error(
        '弹幕插件启动失败',
        details: e.toString(),
      );
    }
  }

  /// Update words in running overlay
  static Future<bool> updateWords(List<Map<String, dynamic>> words) async {
    return sendCommand({
      'cmd': 'WORDS',
      'words': words.map((w) => <String, dynamic>{
        'Word': w['Word'] ?? w['word'] ?? '',
        'Translation': w['Translate'] ?? w['Translation'] ?? w['trans'] ?? '',
        'Example': w['SentenceEn'] ?? w['Example'] ?? w['example'] ?? '',
        'ExampleTrans': w['SentenceCn'] ?? w['ExampleTrans'] ?? w['exampleTrans'] ?? '',
      }).toList(),
    });
  }

  /// Update config in running overlay
  static Future<bool> updateConfig({
    double? areaTop,
    double? areaHeight,
    double? speed,
    double? fontSize,
    int? interval,
    bool? showTranslation,
    String? wordColor,
    String? transColor,
    String? bgColor,
    double? opacity,
    String? examplePosition,
    double? exampleOffsetY,
  }) async {
    final config = <String, dynamic>{};
    if (areaTop != null) config['areaTop'] = areaTop;
    if (areaHeight != null) config['areaHeight'] = areaHeight;
    if (speed != null) config['speed'] = speed;
    if (fontSize != null) config['fontSize'] = fontSize;
    if (interval != null) config['interval'] = interval;
    if (showTranslation != null) config['showTranslation'] = showTranslation;
    if (wordColor != null) config['wordColor'] = wordColor;
    if (transColor != null) config['transColor'] = transColor;
    if (bgColor != null) config['bgColor'] = bgColor;
    if (opacity != null) config['opacity'] = opacity;
    if (examplePosition != null) config['examplePosition'] = examplePosition;
    if (exampleOffsetY != null) config['exampleOffsetY'] = exampleOffsetY;

    return sendCommand({
      'cmd': 'CONFIG',
      'config': config,
    });
  }

  /// Stop the danmu overlay
  static Future<void> stop() async {
    final sent = await sendCommand({'cmd': 'STOP'});
    if (sent) {
      await Future.delayed(const Duration(milliseconds: 500));
    }
    await disconnect();
    
    // Fallback: kill process directly
    try {
      await Process.run('taskkill', ['/F', '/IM', 'DanmuOverlay.exe']);
    } catch (_) {}
  }

  /// Pause the danmu
  static Future<bool> pause() async {
    return sendCommand({'cmd': 'PAUSE'});
  }

  /// Resume the danmu
  static Future<bool> resume() async {
    return sendCommand({'cmd': 'RESUME'});
  }

  /// Check if overlay is running
  static bool get isConnected => _isConnected;

  /// Process received data from overlay (handle complete JSON messages)
  static void _processReceivedData() {
    int newlineIndex;
    while ((newlineIndex = _receiveBuffer.indexOf('\n')) >= 0) {
      final jsonLine = _receiveBuffer.substring(0, newlineIndex).trim();
      _receiveBuffer = _receiveBuffer.substring(newlineIndex + 1);

      if (jsonLine.isNotEmpty) {
        _handleMessage(jsonLine);
      }
    }
  }

  /// Handle a single JSON message from overlay
  static void _handleMessage(String json) {
    try {
      final message = jsonDecode(json) as Map<String, dynamic>;
      final type = message['type'] as String?;

      if (kDebugMode) {
        debugPrint('Danmu received: $type');
      }

      switch (type) {
        case 'WORD_MASTERED':
          final word = message['word'] as String?;
          if (word != null && word.isNotEmpty) {
            _handleWordMastered(word);
          }
          break;
        default:
          if (kDebugMode) {
            debugPrint('Unknown message type: $type');
          }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to parse danmu message: $e');
      }
    }
  }

  /// Handle word mastered event - mark word as mastered in database
  static Future<void> _handleWordMastered(String word) async {
    if (kDebugMode) {
      debugPrint('Word mastered from overlay: $word');
    }

    // Invoke callback if set
    onWordMastered?.call(word);

    // Mark word as mastered in database
    try {
      final db = await DatabaseHelper.database;
      // Find word by text and mark as mastered
      final results = await db.query(
        'WordItem',
        columns: ['WordId'],
        where: 'Word = ?',
        whereArgs: [word],
        limit: 1,
      );

      if (results.isNotEmpty) {
        final wordId = results.first['WordId'] as String;
        final repo = WordRepository();
        await repo.setMastered(wordId);
        if (kDebugMode) {
          debugPrint('Marked "$word" as mastered (WordId: $wordId)');
        }
      } else {
        if (kDebugMode) {
          debugPrint('Word not found in database: $word');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to mark word as mastered: $e');
      }
    }
  }

  /// Find the DanmuOverlay.exe path
  static _DanmuExeFindResult _findDanmuExe() {
    final exeDir = File(Platform.resolvedExecutable).parent.path;

    // 获取项目根目录 (向上查找直到找到 pubspec.yaml 或使用已知路径)
    String projectDir = exeDir;
    // 如果是在 build\windows\x64\runner\Release 下运行，向上4层是项目根目录
    if (exeDir.contains('build\\windows')) {
      projectDir = exeDir.replaceAll(RegExp(r'\\build\\windows.*$'), '');
    }

    // Possible locations (ordered by priority)
    final paths = [
      // Production paths (安装后的路径)
      '$exeDir\\plugins\\DanmuOverlay.exe',
      '$exeDir\\DanmuOverlay.exe',
      // installer_output 中已编译的插件 (开发调试时使用)
      '$projectDir\\installer_output\\extracted\\DanmuOverlay.exe',
      // 项目内的 windows 子项目编译结果
      '$projectDir\\windows\\danmu_overlay\\bin\\Release\\net6.0-windows\\DanmuOverlay.exe',
      '$projectDir\\windows\\danmu_overlay\\bin\\Debug\\net6.0-windows\\DanmuOverlay.exe',
      '$projectDir\\windows\\danmu_overlay\\bin\\Release\\net6.0-windows\\win-x64\\DanmuOverlay.exe',
    ];

    if (kDebugMode) {
      debugPrint('Looking for DanmuOverlay.exe...');
      debugPrint('Exe directory: $exeDir');
      debugPrint('Project directory: $projectDir');
    }

    for (final path in paths) {
      final file = File(path);
      if (file.existsSync()) {
        if (kDebugMode) {
          debugPrint('✅ Found DanmuOverlay at: $path');
        }
        return _DanmuExeFindResult.found(path);
      }
    }

    if (kDebugMode) {
      debugPrint('⚠️ DanmuOverlay.exe not found');
    }
    return _DanmuExeFindResult.notFound(paths);
  }
}
