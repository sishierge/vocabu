import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tts_service.dart';

/// 播放模式
enum PlaybackMode {
  tts,      // 使用系统TTS
  online,   // 使用在线音频
}

/// 播放状态
enum PlaybackState {
  idle,     // 空闲
  loading,  // 加载中
  playing,  // 播放中
  paused,   // 暂停
  completed,// 播放完成
  error,    // 错误
}

/// 统一音频播放服务
/// 封装 TTS 和 AudioPlayer，提供统一的播放接口
class UnifiedAudioService {
  static final UnifiedAudioService instance = UnifiedAudioService._();
  UnifiedAudioService._();

  final AudioPlayer _audioPlayer = AudioPlayer();

  // 播放状态
  PlaybackState _state = PlaybackState.idle;
  PlaybackMode _mode = PlaybackMode.tts;
  double _playbackRate = 1.0;
  String? _currentText;
  String? _currentAudioUrl;

  // 进度信息
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  // 回调
  final _stateController = StreamController<PlaybackState>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();

  // Getters
  PlaybackState get state => _state;
  PlaybackMode get mode => _mode;
  double get playbackRate => _playbackRate;
  Duration get position => _position;
  Duration get duration => _duration;
  bool get isPlaying => _state == PlaybackState.playing;
  bool get isLoading => _state == PlaybackState.loading;

  // Streams
  Stream<PlaybackState> get stateStream => _stateController.stream;
  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration> get durationStream => _durationController.stream;

  /// 初始化服务
  Future<void> initialize() async {
    // 监听 AudioPlayer 状态
    _audioPlayer.onPlayerStateChanged.listen((playerState) {
      switch (playerState) {
        case PlayerState.playing:
          _updateState(PlaybackState.playing);
          break;
        case PlayerState.paused:
          _updateState(PlaybackState.paused);
          break;
        case PlayerState.stopped:
          _updateState(PlaybackState.idle);
          break;
        case PlayerState.completed:
          _updateState(PlaybackState.completed);
          break;
        case PlayerState.disposed:
          break;
      }
    });

    // 监听播放位置
    _audioPlayer.onPositionChanged.listen((position) {
      _position = position;
      _positionController.add(position);
    });

    // 监听音频时长
    _audioPlayer.onDurationChanged.listen((duration) {
      _duration = duration;
      _durationController.add(duration);
    });

    // 监听错误
    _audioPlayer.onLog.listen((msg) {
      if (kDebugMode) {
        debugPrint('AudioPlayer: $msg');
      }
    });

    // 加载保存的语速设置
    final prefs = await SharedPreferences.getInstance();
    _playbackRate = prefs.getDouble('listening_playback_rate') ?? 1.0;

    if (kDebugMode) {
      debugPrint('UnifiedAudioService initialized, rate: $_playbackRate');
    }
  }

  void _updateState(PlaybackState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(newState);
    }
  }

  /// 播放文本（使用TTS或在线音频）
  /// [text] 要播放的英文文本
  /// [audioUrl] 可选的在线音频URL，如果提供则使用在线音频
  Future<void> play({
    required String text,
    String? audioUrl,
  }) async {
    // 停止当前播放
    await stop();

    _currentText = text;
    _currentAudioUrl = audioUrl;
    _updateState(PlaybackState.loading);

    try {
      if (audioUrl != null && audioUrl.isNotEmpty) {
        // 使用在线音频
        _mode = PlaybackMode.online;
        await _audioPlayer.setPlaybackRate(_playbackRate);
        await _audioPlayer.play(UrlSource(audioUrl));

        if (kDebugMode) {
          debugPrint('Playing online audio: $audioUrl');
        }
      } else {
        // 使用 TTS
        _mode = PlaybackMode.tts;
        _updateState(PlaybackState.playing);

        // TTS 语速转换 (0.0-1.0 -> 实际速度)
        final ttsRate = (_playbackRate - 1.0) * 0.5 + 0.5; // 0.5x -> 0.0, 1.0x -> 0.5, 2.0x -> 1.0
        await TtsService.instance.setSpeechRate(ttsRate.clamp(0.0, 1.0));
        await TtsService.instance.speak(text);

        // TTS 播放完成
        _updateState(PlaybackState.completed);

        if (kDebugMode) {
          debugPrint('TTS completed: $text');
        }
      }
    } catch (e) {
      _updateState(PlaybackState.error);
      if (kDebugMode) {
        debugPrint('Play error: $e');
      }
      rethrow;
    }
  }

  /// 暂停播放
  Future<void> pause() async {
    if (_mode == PlaybackMode.online) {
      await _audioPlayer.pause();
    } else {
      // TTS 不支持暂停，直接停止
      await TtsService.instance.stop();
      _updateState(PlaybackState.paused);
    }
  }

  /// 恢复播放
  Future<void> resume() async {
    if (_mode == PlaybackMode.online && _state == PlaybackState.paused) {
      await _audioPlayer.resume();
    } else if (_currentText != null) {
      // TTS 重新播放
      await play(text: _currentText!, audioUrl: _currentAudioUrl);
    }
  }

  /// 停止播放
  Future<void> stop() async {
    TtsService.instance.stop();
    await _audioPlayer.stop();
    _position = Duration.zero;
    _duration = Duration.zero;
    _updateState(PlaybackState.idle);
  }

  /// 跳转到指定位置（仅在线音频支持）
  Future<void> seek(Duration position) async {
    if (_mode == PlaybackMode.online) {
      await _audioPlayer.seek(position);
    }
  }

  /// 设置播放速度 (0.5 - 2.0)
  Future<void> setPlaybackRate(double rate) async {
    _playbackRate = rate.clamp(0.5, 2.0);

    // 保存设置
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('listening_playback_rate', _playbackRate);

    // 如果正在播放，更新速度
    if (_mode == PlaybackMode.online) {
      await _audioPlayer.setPlaybackRate(_playbackRate);
    }
  }

  /// 重播当前内容
  Future<void> replay() async {
    if (_currentText != null) {
      await play(text: _currentText!, audioUrl: _currentAudioUrl);
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    await _stateController.close();
    await _positionController.close();
    await _durationController.close();
    await _audioPlayer.dispose();
  }
}

/// 学习进度服务
class ListeningProgressService {
  static final ListeningProgressService instance = ListeningProgressService._();
  ListeningProgressService._();

  static const String _keyPrefix = 'listening_progress_';

  /// 保存学习进度
  Future<void> saveProgress({
    required String materialId,
    required int currentIndex,
    required int totalCount,
    int playCount = 0,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_keyPrefix${materialId}_index', currentIndex);
    await prefs.setInt('$_keyPrefix${materialId}_total', totalCount);
    await prefs.setInt('$_keyPrefix${materialId}_playCount', playCount);
    await prefs.setInt('$_keyPrefix${materialId}_timestamp', DateTime.now().millisecondsSinceEpoch);
  }

  /// 加载学习进度
  Future<ListeningProgress?> loadProgress(String materialId) async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt('$_keyPrefix${materialId}_index');

    if (index == null) return null;

    return ListeningProgress(
      materialId: materialId,
      currentIndex: index,
      totalCount: prefs.getInt('$_keyPrefix${materialId}_total') ?? 0,
      playCount: prefs.getInt('$_keyPrefix${materialId}_playCount') ?? 0,
      lastStudyTime: DateTime.fromMillisecondsSinceEpoch(
        prefs.getInt('$_keyPrefix${materialId}_timestamp') ?? 0,
      ),
    );
  }

  /// 清除学习进度
  Future<void> clearProgress(String materialId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keyPrefix${materialId}_index');
    await prefs.remove('$_keyPrefix${materialId}_total');
    await prefs.remove('$_keyPrefix${materialId}_playCount');
    await prefs.remove('$_keyPrefix${materialId}_timestamp');
  }

  /// 获取所有有进度的素材ID
  Future<List<String>> getAllProgressMaterialIds() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final materialIds = <String>{};

    for (final key in keys) {
      if (key.startsWith(_keyPrefix) && key.endsWith('_index')) {
        final id = key.substring(_keyPrefix.length, key.length - '_index'.length);
        materialIds.add(id);
      }
    }

    return materialIds.toList();
  }
}

/// 学习进度数据
class ListeningProgress {
  final String materialId;
  final int currentIndex;
  final int totalCount;
  final int playCount;
  final DateTime lastStudyTime;

  ListeningProgress({
    required this.materialId,
    required this.currentIndex,
    required this.totalCount,
    required this.playCount,
    required this.lastStudyTime,
  });

  double get progressPercent => totalCount > 0 ? currentIndex / totalCount : 0;
}
