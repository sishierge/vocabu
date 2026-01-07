import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'local_config_service.dart';

/// Text-to-Speech service using native Windows SAPI
class TtsService {
  static TtsService? _instance;
  FlutterTts? _flutterTts;
  bool _isInitialized = false;

  // Settings
  double _speechRate = 0.5;
  double _volume = 1.0;
  double _pitch = 1.0;
  String? _currentVoice;
  List<dynamic> _availableVoices = [];

  // 播放完成回调
  Completer<void>? _speakCompleter;

  static TtsService get instance {
    _instance ??= TtsService._();
    return _instance!;
  }

  TtsService._();

  /// Initialize the TTS service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _flutterTts = FlutterTts();

      // Read settings from LocalConfigService
      final config = LocalConfigService.instance;
      _speechRate = config.ttsSpeed;
      _volume = config.ttsVolume;

      // Set default parameters
      await _flutterTts!.setVolume(_volume);
      await _flutterTts!.setSpeechRate(_speechRate);
      await _flutterTts!.setPitch(_pitch);

      // Get available voices
      _availableVoices = await _flutterTts!.getVoices ?? [];

      // Try to set English voice
      for (var voice in _availableVoices) {
        if (voice is Map) {
          final locale = voice['locale'] as String? ?? '';
          if (locale.startsWith('en')) {
            await _flutterTts!.setVoice({'name': voice['name'], 'locale': locale});
            _currentVoice = voice['name'] as String?;
            break;
          }
        }
      }

      // Set up handlers
      _flutterTts!.setStartHandler(() {
        if (kDebugMode) {
          debugPrint('TTS started');
        }
      });

      _flutterTts!.setCompletionHandler(() {
        if (kDebugMode) {
          debugPrint('TTS completed');
        }
        // 完成播放回调
        _speakCompleter?.complete();
        _speakCompleter = null;
      });

      _flutterTts!.setErrorHandler((msg) {
        if (kDebugMode) {
          debugPrint('TTS error: $msg');
        }
        // 错误时也完成
        _speakCompleter?.completeError(msg);
        _speakCompleter = null;
      });

      _flutterTts!.setCancelHandler(() {
        if (kDebugMode) {
          debugPrint('TTS cancelled');
        }
        // 取消时也完成
        _speakCompleter?.complete();
        _speakCompleter = null;
      });

      _isInitialized = true;
      if (kDebugMode) {
        debugPrint('TTS service initialized with ${_availableVoices.length} voices');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('TTS initialization error: $e');
      }
    }
  }

  /// Speak a word using native TTS
  /// Returns a Future that completes when speech finishes
  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    if (!_isInitialized) await initialize();

    try {
      // 取消之前的播放
      _speakCompleter?.complete();
      _speakCompleter = null;

      // 创建新的完成器
      _speakCompleter = Completer<void>();

      await _flutterTts?.speak(text);

      // 等待播放完成
      await _speakCompleter?.future;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('TTS speak error: $e');
      }
      _speakCompleter = null;
    }
  }

  /// Stop current speech
  Future<void> stop() async {
    _speakCompleter?.complete();
    _speakCompleter = null;
    await _flutterTts?.stop();
  }

  /// Set speech rate (0.0 - 1.0)
  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate.clamp(0.0, 1.0);
    if (_flutterTts != null) {
      await _flutterTts!.setSpeechRate(_speechRate);
    }
  }

  /// Set volume (0.0 - 1.0)
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    if (_flutterTts != null) {
      await _flutterTts!.setVolume(_volume);
    }
  }

  /// Set pitch (0.5 - 2.0)
  Future<void> setPitch(double pitch) async {
    _pitch = pitch.clamp(0.5, 2.0);
    if (_flutterTts != null) {
      await _flutterTts!.setPitch(_pitch);
    }
  }

  /// Set voice by name
  Future<void> setVoice(String voiceName, String locale) async {
    if (_flutterTts != null) {
      await _flutterTts!.setVoice({'name': voiceName, 'locale': locale});
      _currentVoice = voiceName;
    }
  }

  /// Get available voices
  List<dynamic> get availableVoices => _availableVoices;

  /// Get current voice
  String? get currentVoice => _currentVoice;

  /// Get current speech rate
  double get speechRate => _speechRate;

  /// Get current volume
  double get volume => _volume;

  /// Get current pitch
  double get pitch => _pitch;

  /// Check if service is ready
  bool get isInitialized => _isInitialized;

  /// Dispose
  Future<void> dispose() async {
    await _flutterTts?.stop();
    _isInitialized = false;
  }
}
