import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// 音频播放服务 - 用于播放在线 BBC/VOA 等真实音频
class AudioPlayerService {
  static final AudioPlayerService instance = AudioPlayerService._();
  AudioPlayerService._();

  final AudioPlayer _player = AudioPlayer();

  // 播放状态
  bool _isPlaying = false;
  bool _isLoading = false;
  double _playbackRate = 1.0;

  // 回调
  VoidCallback? onPlayingChanged;
  VoidCallback? onComplete;
  VoidCallback? onError;

  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  double get playbackRate => _playbackRate;

  Future<void> initialize() async {
    // 监听播放状态
    _player.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
      _isLoading = false;
      onPlayingChanged?.call();
    });

    // 监听播放完成
    _player.onPlayerComplete.listen((_) {
      _isPlaying = false;
      onComplete?.call();
    });

    if (kDebugMode) {
      debugPrint('AudioPlayerService initialized');
    }
  }

  /// 播放网络音频
  Future<void> playUrl(String url) async {
    try {
      _isLoading = true;
      onPlayingChanged?.call();

      await _player.stop();
      await _player.setPlaybackRate(_playbackRate);
      await _player.play(UrlSource(url));

      if (kDebugMode) {
        debugPrint('Playing audio: $url');
      }
    } catch (e) {
      _isLoading = false;
      _isPlaying = false;
      if (kDebugMode) {
        debugPrint('Error playing audio: $e');
      }
      onError?.call();
    }
  }

  /// 暂停播放
  Future<void> pause() async {
    await _player.pause();
    _isPlaying = false;
    onPlayingChanged?.call();
  }

  /// 恢复播放
  Future<void> resume() async {
    await _player.resume();
  }

  /// 停止播放
  Future<void> stop() async {
    await _player.stop();
    _isPlaying = false;
    onPlayingChanged?.call();
  }

  /// 设置播放速度 (0.5 - 2.0)
  Future<void> setPlaybackRate(double rate) async {
    _playbackRate = rate.clamp(0.5, 2.0);
    await _player.setPlaybackRate(_playbackRate);
  }

  /// 获取当前播放位置
  Future<Duration> get position async => await _player.getCurrentPosition() ?? Duration.zero;

  /// 获取音频总时长
  Future<Duration> get duration async => await _player.getDuration() ?? Duration.zero;

  /// 跳转到指定位置
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  /// 释放资源
  Future<void> dispose() async {
    await _player.dispose();
  }
}
