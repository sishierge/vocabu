import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:file_selector/file_selector.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../providers/word_book_provider.dart';
import '../../services/import_service.dart';
import '../../services/listening_materials_service.dart';
import '../../services/online_materials_service.dart';
import '../../services/unified_audio_service.dart';
import '../../services/sentence_collection_service.dart';
import '../../services/translation_service.dart';
import 'listening_materials_store_page.dart';
import 'article_listening_page.dart';
import 'collected_sentences_page.dart';
import 'learning_statistics_page.dart';
import '../../services/learning_statistics_service.dart';
import '../../services/listening_settings_service.dart';
import '../../services/custom_materials_service.dart';
import 'custom_materials_page.dart';

/// 听力练习页面 - 句子精听
class ListeningPage extends StatefulWidget {
  final String? bookId;
  final String? bookName;

  const ListeningPage({super.key, this.bookId, this.bookName});

  @override
  State<ListeningPage> createState() => _ListeningPageState();
}

class _ListeningPageState extends State<ListeningPage> {
  List<Map<String, dynamic>> _sentences = [];
  List<AudioMaterial> _audioMaterials = []; // 带音频URL的在线素材
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _useRealAudio = false; // 是否使用真实音频（而不是TTS）
  String? _currentBookId;
  String? _currentMaterialId; // 当前素材ID（用于保存进度）
  String? _currentMaterialName; // 当前素材名称

  // 显示控制
  bool _showEnglish = false;  // 是否显示英文原文
  bool _showChinese = false;  // 是否显示中文翻译
  bool _isLoopMode = false;   // 单句循环模式
  bool _isAutoNextMode = false; // 自动下一句模式
  int _autoNextDelay = 2;     // 自动下一句延迟（秒）

  // 播放状态
  PlaybackState _playbackState = PlaybackState.idle;
  StreamSubscription<PlaybackState>? _stateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  // 播放次数统计
  int _playCount = 0;

  // 语速控制
  double _speechRate = 0.5; // 0.2-1.0 对应 0.4x-2.0x

  // 听写模式
  bool _isDictationMode = false;
  final TextEditingController _dictationController = TextEditingController();
  bool _showDictationResult = false;
  List<DictationWord>? _dictationAnalysis; // 听写分析结果

  // 语音高亮跟随
  int _highlightedWordIndex = -1;
  List<String> _currentWords = [];
  Timer? _highlightTimer;

  // AB段复读
  bool _isABRepeatMode = false;
  int _pointA = -1; // A点句子索引
  int _pointB = -1; // B点句子索引

  // 句子收藏
  bool _isCurrentCollected = false;
  bool _isCurrentDifficult = false;

  // 查词弹窗
  OverlayEntry? _wordPopup;
  String? _selectedWord;

  // 跟读打分
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;
  String _recognizedText = '';
  double _pronunciationScore = 0.0;
  bool _showPronunciationResult = false;

  // 键盘焦点
  final FocusNode _focusNode = FocusNode();

  // === 新功能：睡眠定时器 ===
  Timer? _sleepTimer;
  int _sleepMinutes = 0; // 0表示关闭
  int _sleepRemaining = 0; // 剩余秒数


  // === 新功能：循环模式选择 ===
  // 0=不循环, 1=单句循环, 2=AB段循环, 3=全部循环
  int _loopModeIndex = 0;

  @override
  void initState() {
    super.initState();
    _initServices();
    _loadSentences();
  }

  Future<void> _initServices() async {
    await UnifiedAudioService.instance.initialize();
    await SentenceCollectionService.instance.initialize();
    await LearningStatisticsService.instance.initialize();
    await ListeningSettingsService.instance.initialize();
    await CustomMaterialsService.instance.initialize();
    _loadSettings();
    _initAudioService();
    _initSpeechRecognition();
  }

  /// 加载保存的设置
  void _loadSettings() {
    final settings = ListeningSettingsService.instance;
    setState(() {
      _speechRate = settings.speechRate;
      _isLoopMode = settings.loopMode;
      _isAutoNextMode = settings.autoNext;
      _autoNextDelay = settings.autoNextDelay;
    });
  }

  /// 初始化语音识别
  Future<void> _initSpeechRecognition() async {
    try {
      _speechAvailable = await _speech.initialize(
        onStatus: (status) {
          if (kDebugMode) {
            debugPrint('Speech status: $status');
          }
          if (status == 'done' || status == 'notListening') {
            if (mounted && _isListening) {
              setState(() => _isListening = false);
              _calculatePronunciationScore();
            }
          }
        },
        onError: (error) {
          if (kDebugMode) {
            debugPrint('Speech error: $error');
          }
          if (mounted) {
            setState(() => _isListening = false);
          }
        },
      );
      if (kDebugMode) {
        debugPrint('Speech recognition available: $_speechAvailable');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Speech init error: $e');
      }
      _speechAvailable = false;
    }
  }

  void _initAudioService() {

    // 监听播放状态
    _stateSubscription = UnifiedAudioService.instance.stateStream.listen((state) {
      if (mounted) {
        final wasPlaying = _isPlaying;
        setState(() => _playbackState = state);

        // 开始播放时启动高亮跟随
        if (state == PlaybackState.playing && !wasPlaying && _showEnglish) {
          _startHighlightTracking();
        }

        // 停止播放时停止高亮跟随
        if (state != PlaybackState.playing && wasPlaying) {
          _stopHighlightTracking();
        }

        // 播放完成时的处理
        if (state == PlaybackState.completed) {
          _playCount++;
          _saveProgress();
          // 记录统计
          LearningStatisticsService.instance.addPlayCount(1);

          // AB复读模式
          if (_isABRepeatMode && _pointA >= 0 && _pointB >= 0 && mounted) {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (!mounted) return;
              if (_currentIndex < _pointB) {
                // 播放下一句
                _jumpToSentence(_currentIndex + 1);
              } else {
                // 回到A点
                _jumpToSentence(_pointA);
              }
            });
          }
          // 单句循环模式
          else if (_isLoopMode && mounted) {
            Future.delayed(const Duration(milliseconds: 1000), () {
              if (_isLoopMode && mounted) {
                _playSentence();
              }
            });
          }
          // 自动下一句模式
          else if (_isAutoNextMode && mounted && _currentIndex < _sentences.length - 1) {
            Future.delayed(Duration(seconds: _autoNextDelay), () {
              if (_isAutoNextMode && mounted) {
                _nextSentence();
              }
            });
          }
        }
      }
    });

    // 监听播放位置
    _positionSubscription = UnifiedAudioService.instance.positionStream.listen((pos) {
      if (mounted) {
        setState(() => _position = pos);
      }
    });

    // 监听音频时长
    _durationSubscription = UnifiedAudioService.instance.durationStream.listen((dur) {
      if (mounted) {
        setState(() => _duration = dur);
        // 获取到时长后启动高亮跟随
        if (_isPlaying && _showEnglish && dur.inMilliseconds > 0) {
          _startHighlightTracking();
        }
      }
    });
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _dictationController.dispose();
    _highlightTimer?.cancel();
    _sleepTimer?.cancel(); // 清理睡眠定时器
    _wordPopup?.remove();
    _focusNode.dispose();
    UnifiedAudioService.instance.stop();
    _saveProgress(); // 退出时保存进度
    super.dispose();
  }

  // === 睡眠定时器功能 ===
  /// 设置睡眠定时器
  void _setSleepTimer(int minutes) {
    _sleepTimer?.cancel();
    setState(() {
      _sleepMinutes = minutes;
      _sleepRemaining = minutes * 60;
    });

    if (minutes <= 0) return;

    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _sleepRemaining--;
      });

      if (_sleepRemaining <= 0) {
        timer.cancel();
        _stopPlaying();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('定时已到，播放已停止')),
          );
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('将在 $minutes 分钟后自动停止')),
    );
  }

  /// 显示睡眠定时器选择对话框
  void _showSleepTimerDialog() {
    final colorScheme = Theme.of(context).colorScheme;
    final options = [0, 5, 10, 15, 20, 30, 45, 60]; // 分钟选项

    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bedtime, color: colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  '睡眠定时器',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_sleepMinutes > 0) ...[
                  const Spacer(),
                  Text(
                    '剩余 ${_sleepRemaining ~/ 60}:${(_sleepRemaining % 60).toString().padLeft(2, '0')}',
                    style: TextStyle(color: colorScheme.primary, fontSize: 14),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: options.map((min) {
                final isSelected = _sleepMinutes == min;
                return ChoiceChip(
                  label: Text(min == 0 ? '关闭' : '$min 分钟'),
                  selected: isSelected,
                  selectedColor: colorScheme.primary.withValues(alpha: 0.2),
                  onSelected: (_) {
                    Navigator.pop(context);
                    _setSleepTimer(min);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // === 句子导航功能 ===
  /// 显示句子导航面板
  void _showSentenceNavigator() {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surfaceContainer,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.list, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Text(
                    '句子列表 (${_currentIndex + 1}/${_sentences.length})',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: colorScheme.onSurfaceVariant),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(color: colorScheme.outlineVariant, height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _sentences.length,
                itemBuilder: (context, index) {
                  final sentence = _sentences[index];
                  final english = sentence['SentenceText'] as String? ??
                      sentence['SentenceEn'] as String? ?? '';
                  final isCurrent = index == _currentIndex;

                  return ListTile(
                    leading: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? colorScheme.primary
                            : colorScheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: isCurrent
                                ? colorScheme.onPrimary
                                : colorScheme.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      english,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isCurrent ? colorScheme.primary : colorScheme.onSurface,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                    trailing: isCurrent
                        ? Icon(Icons.play_circle, color: colorScheme.primary)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      _jumpToSentence(index);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // === 循环模式控制 ===
  /// 切换循环模式
  void _toggleLoopMode() {
    setState(() {
      _loopModeIndex = (_loopModeIndex + 1) % 4;

      // 同步更新原有的循环状态变量
      _isLoopMode = _loopModeIndex == 1;
      _isAutoNextMode = _loopModeIndex == 3;

      // 如果是AB循环模式但没有设置AB点，提示用户
      if (_loopModeIndex == 2 && (_pointA < 0 || _pointB < 0)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先设置A点和B点')),
        );
      }
    });

    // 保存设置
    ListeningSettingsService.instance.setLoopMode(_isLoopMode);
    ListeningSettingsService.instance.setAutoNext(_isAutoNextMode);
  }

  /// 获取循环模式图标
  IconData _getLoopModeIcon() {
    switch (_loopModeIndex) {
      case 1: return Icons.repeat_one; // 单句循环
      case 2: return Icons.repeat_on; // AB段循环
      case 3: return Icons.repeat; // 全部循环
      default: return Icons.repeat; // 不循环
    }
  }

  /// 获取循环模式文字
  String _getLoopModeLabel() {
    switch (_loopModeIndex) {
      case 1: return '单句循环';
      case 2: return 'AB循环';
      case 3: return '全部循环';
      default: return '不循环';
    }
  }

  /// 处理键盘事件
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (_isDictationMode) return KeyEventResult.ignored; // 听写模式下不处理

    switch (event.logicalKey) {
      case LogicalKeyboardKey.space:
        if (_isPlaying) {
          _stopPlaying();
        } else {
          _playSentence();
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft:
        _prevSentence();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        _nextSentence();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyR:
        _playSentence();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyE:
        setState(() => _showEnglish = !_showEnglish);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyC:
        setState(() => _showChinese = !_showChinese);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyL:
        setState(() => _isLoopMode = !_isLoopMode);
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  /// 保存学习进度
  Future<void> _saveProgress() async {
    if (_currentMaterialId != null && _sentences.isNotEmpty) {
      await ListeningProgressService.instance.saveProgress(
        materialId: _currentMaterialId!,
        currentIndex: _currentIndex,
        totalCount: _sentences.length,
        playCount: _playCount,
      );
    }
  }

  /// 加载学习进度
  Future<void> _loadProgress(String materialId) async {
    final progress = await ListeningProgressService.instance.loadProgress(materialId);
    if (progress != null && progress.currentIndex < _sentences.length) {
      setState(() {
        _currentIndex = progress.currentIndex;
        _playCount = progress.playCount;
      });
    }
  }

  Future<void> _loadSentences() async {
    setState(() => _isLoading = true);

    final provider = WordBookProvider.instance;
    final bookId = widget.bookId ?? provider.books.firstOrNull?.bookId;
    _currentBookId = bookId;

    if (bookId != null) {
      // 优先加载句子
      var sentences = await provider.getSentencesForBook(bookId, limit: 100);

      // 如果没有句子，用单词的例句
      if (sentences.isEmpty) {
        final words = await provider.getWordsForBook(bookId, limit: 100);
        sentences = words.where((w) =>
          (w['Example'] as String? ?? '').isNotEmpty ||
          (w['SentenceEn'] as String? ?? '').isNotEmpty
        ).map((w) => <String, dynamic>{
          'SentenceText': w['SentenceEn'] ?? w['Example'] ?? '',
          'SentenceCn': w['SentenceCn'] ?? w['ExampleTrans'] ?? w['Translate'] ?? '',
          'Word': w['Word'] ?? '',
        }).toList();
      }

      setState(() {
        _sentences = sentences;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic>? get _currentSentence =>
      _sentences.isNotEmpty && _currentIndex < _sentences.length
          ? _sentences[_currentIndex]
          : null;

  String get _englishText =>
      _currentSentence?['SentenceText'] as String? ??
      _currentSentence?['SentenceEn'] as String? ?? '';

  String get _chineseText =>
      _currentSentence?['Translate'] as String? ??
      _currentSentence?['SentenceCn'] as String? ?? '';

  bool get _isPlaying => _playbackState == PlaybackState.playing;
  bool get _isAudioLoading => _playbackState == PlaybackState.loading;

  /// 格式化时长显示
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// 更新收藏状态
  void _updateCollectionStatus() {
    if (_englishText.isEmpty) return;
    setState(() {
      _isCurrentCollected = SentenceCollectionService.instance.isCollected(_englishText);
      _isCurrentDifficult = SentenceCollectionService.instance.isDifficult(_englishText);
    });
  }

  /// 收藏/取消收藏当前句子
  Future<void> _toggleCollect() async {
    if (_englishText.isEmpty) return;

    if (_isCurrentCollected) {
      await SentenceCollectionService.instance.uncollectSentence(_englishText);
    } else {
      await SentenceCollectionService.instance.collectSentence(CollectedSentence(
        english: _englishText,
        chinese: _chineseText,
        materialName: _currentMaterialName,
        audioUrl: _useRealAudio && _audioMaterials.isNotEmpty && _currentIndex < _audioMaterials.length
            ? _audioMaterials[_currentIndex].audioUrl
            : null,
      ));
    }
    _updateCollectionStatus();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isCurrentCollected ? '已收藏' : '已取消收藏'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  /// 标记/取消标记为难句
  Future<void> _toggleDifficult() async {
    if (_englishText.isEmpty) return;

    if (_isCurrentDifficult) {
      await SentenceCollectionService.instance.unmarkDifficult(_englishText);
    } else {
      await SentenceCollectionService.instance.markAsDifficult(CollectedSentence(
        english: _englishText,
        chinese: _chineseText,
        materialName: _currentMaterialName,
      ));
    }
    _updateCollectionStatus();
  }

  /// 开始语音高亮跟随
  void _startHighlightTracking() {
    _currentWords = _englishText.split(RegExp(r'\s+'));
    if (_currentWords.isEmpty || _duration.inMilliseconds == 0) return;

    // 估算每个单词的播放时间
    final msPerWord = _duration.inMilliseconds / _currentWords.length;

    _highlightTimer?.cancel();
    _highlightTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!_isPlaying) {
        timer.cancel();
        setState(() => _highlightedWordIndex = -1);
        return;
      }

      final newIndex = (_position.inMilliseconds / msPerWord).floor();
      if (newIndex != _highlightedWordIndex && newIndex < _currentWords.length) {
        setState(() => _highlightedWordIndex = newIndex);
      }
    });
  }

  /// 停止语音高亮跟随
  void _stopHighlightTracking() {
    _highlightTimer?.cancel();
    setState(() => _highlightedWordIndex = -1);
  }

  /// 设置AB复读的A点
  void _setPointA() {
    setState(() {
      _pointA = _currentIndex;
      _pointB = -1;
      _isABRepeatMode = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('A点已设置: 第${_currentIndex + 1}句'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  /// 设置AB复读的B点并开始复读
  void _setPointB() {
    if (_pointA < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先设置A点')),
      );
      return;
    }

    setState(() {
      _pointB = _currentIndex;
      _isABRepeatMode = true;
    });

    // 从A点开始播放
    _jumpToSentence(_pointA);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('AB复读: 第${_pointA + 1}句 - 第${_pointB + 1}句'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 清除AB复读
  void _clearABRepeat() {
    setState(() {
      _pointA = -1;
      _pointB = -1;
      _isABRepeatMode = false;
    });
  }

  /// 跳转到指定句子
  void _jumpToSentence(int index) {
    if (index < 0 || index >= _sentences.length) return;

    setState(() {
      _currentIndex = index;
      _showEnglish = false;
      _showChinese = false;
      _playCount = 0;
      _showDictationResult = false;
      _dictationController.clear();
      _highlightedWordIndex = -1;
    });
    _updateCollectionStatus();
    _playSentence();
  }

  /// 显示查词弹窗
  void _showWordLookup(String word, Offset position) async {
    _wordPopup?.remove();
    _selectedWord = word.replaceAll(RegExp(r'[^\w]'), '').toLowerCase();

    if (_selectedWord!.isEmpty) return;

    // 显示加载中
    _wordPopup = OverlayEntry(
      builder: (context) => _WordLookupPopup(
        word: _selectedWord!,
        position: position,
        onClose: () {
          _wordPopup?.remove();
          _wordPopup = null;
        },
      ),
    );

    Overlay.of(context).insert(_wordPopup!);
  }

  /// 开始跟读
  Future<void> _startListening() async {
    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('语音识别不可用，请检查麦克风权限')),
      );
      return;
    }

    // 先停止当前播放
    await UnifiedAudioService.instance.stop();

    setState(() {
      _isListening = true;
      _recognizedText = '';
      _showPronunciationResult = false;
    });

    await _speech.listen(
      onResult: (result) {
        if (mounted) {
          setState(() {
            _recognizedText = result.recognizedWords;
          });
        }
      },
      localeId: 'en_US',
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.confirmation,
        cancelOnError: true,
        partialResults: true,
      ),
    );
  }

  /// 停止跟读
  Future<void> _stopListening() async {
    await _speech.stop();
    if (mounted) {
      setState(() => _isListening = false);
      _calculatePronunciationScore();
    }
  }

  /// 计算发音得分
  void _calculatePronunciationScore() {
    if (_recognizedText.isEmpty || _englishText.isEmpty) {
      setState(() {
        _pronunciationScore = 0;
        _showPronunciationResult = true;
      });
      return;
    }

    final targetWords = _normalizeForScoring(_englishText).split(RegExp(r'\s+'));
    final spokenWords = _normalizeForScoring(_recognizedText).split(RegExp(r'\s+'));

    if (targetWords.isEmpty) {
      setState(() {
        _pronunciationScore = 0;
        _showPronunciationResult = true;
      });
      return;
    }

    // 使用 LCS 算法计算匹配度
    int matchCount = 0;
    final spokenSet = spokenWords.toSet();

    for (final word in targetWords) {
      if (spokenSet.contains(word)) {
        matchCount++;
      }
    }

    // 基本匹配分数
    double baseScore = (matchCount / targetWords.length) * 100;

    // 额外奖励：如果识别的单词顺序正确
    int orderBonus = 0;
    int lastFoundIndex = -1;
    for (final word in targetWords) {
      final index = spokenWords.indexOf(word);
      if (index > lastFoundIndex) {
        orderBonus++;
        lastFoundIndex = index;
      }
    }
    double orderScore = (orderBonus / targetWords.length) * 20;

    setState(() {
      _pronunciationScore = (baseScore + orderScore).clamp(0, 100);
      _showPronunciationResult = true;
    });

    // 记录发音统计
    LearningStatisticsService.instance.addPronunciationScore(_pronunciationScore);
  }

  /// 规范化文本用于打分
  String _normalizeForScoring(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z0-9\s']"), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// 重置跟读结果
  void _resetPronunciationResult() {
    setState(() {
      _recognizedText = '';
      _pronunciationScore = 0;
      _showPronunciationResult = false;
    });
  }

  Future<void> _playSentence() async {
    if (_englishText.isEmpty) return;

    try {
      // 获取音频URL（如果有的话）
      String? audioUrl;
      if (_useRealAudio && _audioMaterials.isNotEmpty && _currentIndex < _audioMaterials.length) {
        audioUrl = _audioMaterials[_currentIndex].audioUrl;
      }

      await UnifiedAudioService.instance.play(
        text: _englishText,
        audioUrl: audioUrl,
      );
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('播放失败，请重试', retry: _playSentence);
      }
    }
  }

  void _stopPlaying() {
    UnifiedAudioService.instance.stop();
    setState(() => _isLoopMode = false);
  }

  /// 延迟3秒后重播当前句子
  void _delayedReplay() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('3秒后自动重播...'),
        duration: Duration(seconds: 2),
      ),
    );
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _playSentence();
      }
    });
  }

  /// 构建语速选择按钮
  Widget _buildSpeedButton(double speed, String label) {
    final colorScheme = Theme.of(context).colorScheme;
    // 将 speed (0.5-1.5) 转换为 _speechRate (0.25-0.75)
    final targetRate = speed / 2;
    final isSelected = (_speechRate - targetRate).abs() < 0.05;

    return GestureDetector(
      onTap: () {
        setState(() => _speechRate = targetRate);
        ListeningSettingsService.instance.setSpeechRate(targetRate);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: isSelected ? null : Border.all(color: colorScheme.outlineVariant),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  /// 显示错误提示（带重试按钮）
  void _showErrorSnackBar(String message, {VoidCallback? retry}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        action: retry != null
            ? SnackBarAction(
                label: '重试',
                textColor: Colors.white,
                onPressed: retry,
              )
            : null,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _nextSentence() {
    if (_currentIndex < _sentences.length - 1) {
      setState(() {
        _currentIndex++;
        _showEnglish = false;
        _showChinese = false;
        _playCount = 0;
        _showDictationResult = false;
        _dictationController.clear();
      });
      // 记录练习句子统计
      LearningStatisticsService.instance.addPracticedSentences(1);
      _playSentence();
    }
  }

  void _prevSentence() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _showEnglish = false;
        _showChinese = false;
        _playCount = 0;
        _showDictationResult = false;
        _dictationController.clear();
      });
      _playSentence();
    }
  }

  void _checkDictation() {
    final analysis = _analyzeDictation(_dictationController.text, _englishText);
    setState(() {
      _showDictationResult = true;
      _dictationAnalysis = analysis;
    });

    // 记录听写统计
    final correct = analysis.where((w) => w.isCorrect).length;
    LearningStatisticsService.instance.addDictationResult(correct, analysis.length);
  }

  /// 分析听写结果，返回每个单词的正确/错误状态
  List<DictationWord> _analyzeDictation(String input, String target) {
    final inputWords = _normalizeText(input).split(RegExp(r'\s+'));
    final targetWords = _normalizeText(target).split(RegExp(r'\s+'));
    final result = <DictationWord>[];

    // 使用动态规划计算最长公共子序列
    final m = inputWords.length;
    final n = targetWords.length;
    final dp = List.generate(m + 1, (_) => List.filled(n + 1, 0));

    for (var i = 1; i <= m; i++) {
      for (var j = 1; j <= n; j++) {
        if (_isSimilarWord(inputWords[i - 1], targetWords[j - 1])) {
          dp[i][j] = dp[i - 1][j - 1] + 1;
        } else {
          dp[i][j] = dp[i - 1][j] > dp[i][j - 1] ? dp[i - 1][j] : dp[i][j - 1];
        }
      }
    }

    // 回溯找出匹配结果
    final matchedTargetIndices = <int>{};
    var i = m;
    var j = n;
    while (i > 0 && j > 0) {
      if (_isSimilarWord(inputWords[i - 1], targetWords[j - 1])) {
        matchedTargetIndices.add(j - 1);
        i--;
        j--;
      } else if (dp[i - 1][j] > dp[i][j - 1]) {
        i--;
      } else {
        j--;
      }
    }

    // 生成结果
    for (var idx = 0; idx < targetWords.length; idx++) {
      final isCorrect = matchedTargetIndices.contains(idx);
      result.add(DictationWord(
        word: targetWords[idx],
        isCorrect: isCorrect,
        userInput: isCorrect ? targetWords[idx] : null,
      ));
    }

    return result;
  }

  /// 规范化文本（去除标点、转小写）
  String _normalizeText(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .trim();
  }

  /// 检查两个单词是否相似（允许小的拼写错误）
  bool _isSimilarWord(String a, String b) {
    if (a == b) return true;

    // 计算编辑距离
    final distance = _levenshteinDistance(a, b);
    // 允许的最大错误数（单词越长，允许的错误越多）
    final maxErrors = (a.length / 4).ceil();
    return distance <= maxErrors;
  }

  /// 计算编辑距离（Levenshtein distance）
  int _levenshteinDistance(String a, String b) {
    final m = a.length;
    final n = b.length;

    if (m == 0) return n;
    if (n == 0) return m;

    final dp = List.generate(m + 1, (i) => List.generate(n + 1, (j) => i == 0 ? j : (j == 0 ? i : 0)));

    for (var i = 1; i <= m; i++) {
      for (var j = 1; j <= n; j++) {
        if (a[i - 1] == b[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1];
        } else {
          dp[i][j] = 1 + [dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1]].reduce((a, b) => a < b ? a : b);
        }
      }
    }

    return dp[m][n];
  }

  // 计算听写正确率
  double _getDictationAccuracy() {
    if (_dictationAnalysis == null || _dictationAnalysis!.isEmpty) return 0;
    final correct = _dictationAnalysis!.where((w) => w.isCorrect).length;
    return correct / _dictationAnalysis!.length;
  }

  // 导入听力素材
  Future<void> _showImportDialog() async {
    if (_currentBookId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择一个词书')),
      );
      return;
    }

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _ImportListeningDialog(bookId: _currentBookId!),
    );

    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result)),
      );
      // 重新加载句子
      _loadSentences();
    }
  }

  // 显示素材选择器
  void _showMaterialPicker() {
    final colorScheme = Theme.of(context).colorScheme;
    final customMaterials = CustomMaterialsService.instance.materials;

    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surfaceContainer,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.library_music, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Text(
                    '选择听力素材',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: colorScheme.onSurfaceVariant),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(color: colorScheme.outlineVariant, height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  // 自定义素材部分
                  if (customMaterials.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Icon(Icons.folder, size: 18, color: colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            '我的素材',
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...customMaterials.map((material) {
                      final isSelected = _currentMaterialId == 'custom_${material.id}';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? colorScheme.primary.withValues(alpha: 0.2) : colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected ? Border.all(color: colorScheme.primary, width: 2) : null,
                        ),
                        child: ListTile(
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.folder, color: colorScheme.primary),
                          ),
                          title: Text(
                            material.name,
                            style: TextStyle(
                              color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            '${material.sentenceCount} 句 · ${material.difficulty}',
                            style: TextStyle(color: colorScheme.outline, fontSize: 12),
                          ),
                          trailing: isSelected
                              ? Icon(Icons.check_circle, color: colorScheme.primary)
                              : Icon(Icons.play_circle_outline, color: colorScheme.outline),
                          onTap: () async {
                            Navigator.pop(context);
                            await _loadCustomMaterial(material);
                          },
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    Divider(color: colorScheme.outlineVariant),
                    const SizedBox(height: 16),
                  ],
                  // 系统素材部分
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Icon(Icons.library_music, size: 18, color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Text(
                          '系统素材',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...ListeningMaterialsService.sources.map((source) {
                    final isSelected = _currentMaterialName == source.name;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? colorScheme.primary.withValues(alpha: 0.2) : colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected ? Border.all(color: colorScheme.primary, width: 2) : null,
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(source.icon, style: const TextStyle(fontSize: 22)),
                          ),
                        ),
                        title: Text(
                          source.name,
                          style: TextStyle(
                            color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          '${source.sentenceCount} 句 · ${source.difficulty}',
                          style: TextStyle(color: colorScheme.outline, fontSize: 12),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle, color: colorScheme.primary)
                            : Icon(Icons.play_circle_outline, color: colorScheme.outline),
                        onTap: () async {
                          Navigator.pop(context);
                          await _loadMaterialFromService(source);
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 加载自定义素材
  Future<void> _loadCustomMaterial(CustomMaterial material) async {
    setState(() => _isLoading = true);

    try {
      final sentences = CustomMaterialsService.instance.getMaterialSentences(material.id);

      if (sentences.isNotEmpty) {
        setState(() {
          _audioMaterials = [];
          _sentences = sentences.map((s) => <String, dynamic>{
            'SentenceText': s['en'] ?? '',
            'Translate': s['cn'] ?? '',
            'SentenceCn': s['cn'] ?? '',
          }).toList();
          _useRealAudio = false;
          _currentMaterialId = 'custom_${material.id}';
          _currentMaterialName = material.name;
          _currentIndex = 0;
          _isLoading = false;
          _showEnglish = false;
          _showChinese = false;
          _playCount = 0;
          _dictationAnalysis = null;
        });

        _playSentence();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('素材没有句子内容')),
          );
        }
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading custom material: $e');
      }
      setState(() => _isLoading = false);
    }
  }

  // 从服务直接加载素材
  Future<void> _loadMaterialFromService(MaterialSource source) async {
    setState(() => _isLoading = true);

    try {
      // 检查是否是在线素材（支持真实音频）
      final onlineSourceIds = OnlineMaterialsService.sources.map((s) => s.id).toSet();
      final isOnlineSource = onlineSourceIds.contains(source.id);

      if (isOnlineSource) {
        // 加载带音频URL的在线素材
        final audioMaterials = await OnlineMaterialsService.instance.fetchOnlineMaterialWithAudio(source.id);

        if (audioMaterials.isNotEmpty) {
          setState(() {
            _audioMaterials = audioMaterials;
            _sentences = audioMaterials.map((m) => <String, dynamic>{
              'SentenceText': m.english,
              'Translate': m.chinese,
              'SentenceCn': m.chinese,
              'audioUrl': m.audioUrl,
            }).toList();
            _useRealAudio = true;
            _currentMaterialId = source.id;
            _currentMaterialName = '${source.name} (在线音频)';
            _currentIndex = 0;
            _isLoading = false;
            _showEnglish = false;
            _showChinese = false;
            _playCount = 0;
            _dictationAnalysis = null;
          });

          // 加载之前的学习进度
          await _loadProgress(source.id);

          // 自动播放当前句
          _playSentence();
          return;
        }
      }

      // 普通素材（使用TTS）
      final sentences = await ListeningMaterialsService.instance.fetchMaterialContent(source.id);

      if (sentences.isNotEmpty) {
        setState(() {
          _audioMaterials = [];
          _sentences = sentences.map((s) => <String, dynamic>{
            'SentenceText': s['en'] ?? '',
            'Translate': s['cn'] ?? '',
            'SentenceCn': s['cn'] ?? '',
          }).toList();
          _useRealAudio = false;
          _currentMaterialId = source.id;
          _currentMaterialName = source.name;
          _currentIndex = 0;
          _isLoading = false;
          _showEnglish = false;
          _showChinese = false;
          _playCount = 0;
          _dictationAnalysis = null;
        });

        // 加载之前的学习进度
        await _loadProgress(source.id);

        // 自动播放当前句
        _playSentence();
      } else {
        if (mounted) {
          _showErrorSnackBar('加载素材失败，请检查网络', retry: () => _loadMaterialFromService(source));
        }
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading material: $e');
      }
      if (mounted) {
        _showErrorSnackBar('加载失败，请稍后重试', retry: () => _loadMaterialFromService(source));
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          backgroundColor: colorScheme.surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
            onPressed: () {
              _stopPlaying();
              Navigator.pop(context);
            },
          ),
          title: Text(
            _currentMaterialName ?? widget.bookName ?? '听力练习',
          style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
        ),
        actions: [
          // 收藏句子按钮
          IconButton(
            icon: Icon(Icons.favorite_border, color: colorScheme.onSurfaceVariant),
            onPressed: () {
              _stopPlaying();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CollectedSentencesPage(),
                ),
              );
            },
            tooltip: '收藏句子',
          ),
          // 学习统计按钮
          IconButton(
            icon: Icon(Icons.bar_chart, color: colorScheme.onSurfaceVariant),
            onPressed: () {
              _stopPlaying();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LearningStatisticsPage(),
                ),
              );
            },
            tooltip: '学习统计',
          ),
          // 切换素材按钮
          IconButton(
            icon: Icon(Icons.library_music, color: colorScheme.primary),
            onPressed: _showMaterialPicker,
            tooltip: '切换素材',
          ),
          // 素材库按钮
          IconButton(
            icon: Icon(Icons.store_outlined, color: colorScheme.onSurfaceVariant),
            onPressed: _openMaterialsStore,
            tooltip: '素材库',
          ),
          // 我的素材按钮
          IconButton(
            icon: Icon(Icons.folder_outlined, color: colorScheme.onSurfaceVariant),
            onPressed: () {
              _stopPlaying();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CustomMaterialsPage()),
              );
            },
            tooltip: '我的素材',
          ),
          // 文章模式按钮
          IconButton(
            icon: Icon(Icons.article_outlined, color: colorScheme.onSurfaceVariant),
            onPressed: () {
              _stopPlaying();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ArticleListeningPage(),
                ),
              );
            },
            tooltip: '文章模式',
          ),
          // 导入按钮
          IconButton(
            icon: Icon(Icons.file_upload_outlined, color: colorScheme.onSurfaceVariant),
            onPressed: _showImportDialog,
            tooltip: '导入听力素材',
          ),
          // 听写模式切换
          IconButton(
            icon: Icon(
              _isDictationMode ? Icons.edit_note : Icons.edit_note_outlined,
              color: _isDictationMode ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
            onPressed: () => setState(() {
              _isDictationMode = !_isDictationMode;
              _showDictationResult = false;
              _dictationController.clear();
            }),
            tooltip: '听写模式',
          ),
          // === 新功能按钮 ===
          // 睡眠定时器
          IconButton(
            icon: Stack(
              children: [
                Icon(
                  Icons.bedtime,
                  color: _sleepMinutes > 0 ? colorScheme.primary : colorScheme.onSurfaceVariant,
                ),
                if (_sleepMinutes > 0)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${_sleepRemaining ~/ 60}',
                        style: TextStyle(color: colorScheme.onPrimary, fontSize: 8),
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: _showSleepTimerDialog,
            tooltip: _sleepMinutes > 0 ? '定时剩余 ${_sleepRemaining ~/ 60} 分钟' : '睡眠定时器',
          ),
          // 句子导航
          IconButton(
            icon: Icon(Icons.format_list_numbered, color: colorScheme.onSurfaceVariant),
            onPressed: _showSentenceNavigator,
            tooltip: '句子列表',
          ),
          // 设置按钮
          IconButton(
            icon: Icon(Icons.settings, color: colorScheme.onSurfaceVariant),
            onPressed: _showSettingsDialog,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
          : _sentences.isEmpty
              ? _buildEmptyState()
              : GestureDetector(
                  // 手势操作：左右滑动切换句子
                  onHorizontalDragEnd: (details) {
                    if (details.primaryVelocity == null) return;
                    if (details.primaryVelocity! < -200) {
                      // 向左滑动 -> 下一句
                      _nextSentence();
                    } else if (details.primaryVelocity! > 200) {
                      // 向右滑动 -> 上一句
                      _prevSentence();
                    }
                  },
                  // 双击重播
                  onDoubleTap: _playSentence,
                  child: Column(
                    children: [
                      // 进度指示
                      _buildProgressBar(),

                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              const SizedBox(height: 20),

                              // 播放控制区
                              _buildPlayControl(),

                              const SizedBox(height: 32),

                              // 句子显示区
                              _buildSentenceCard(),

                              const SizedBox(height: 24),

                              // 听写输入区（听写模式）
                              if (_isDictationMode) _buildDictationArea(),

                              // 显示控制按钮
                              if (!_isDictationMode) _buildShowControls(),
                            ],
                          ),
                        ),
                      ),

                      // 底部控制栏
                      _buildBottomControls(),
                    ],
                  ),
                ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.headphones_outlined, size: 64, color: colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            '暂无听力材料',
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            '从素材库下载或导入自己的素材',
            style: TextStyle(color: colorScheme.outline, fontSize: 13),
          ),
          const SizedBox(height: 24),
          // 素材库按钮
          ElevatedButton.icon(
            onPressed: _openMaterialsStore,
            icon: const Icon(Icons.store),
            label: const Text('素材库'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
          ),
          const SizedBox(height: 12),
          // 导入按钮
          OutlinedButton.icon(
            onPressed: _showImportDialog,
            icon: const Icon(Icons.file_upload, size: 18),
            label: const Text('导入素材'),
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.onSurfaceVariant,
              side: BorderSide(color: colorScheme.outline),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openMaterialsStore() async {
    if (_currentBookId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择一个词书')),
      );
      return;
    }

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ListeningMaterialsStorePage(bookId: _currentBookId!),
      ),
    );

    if (result == true && mounted) {
      _loadSentences();
    }
  }

  Widget _buildProgressBar() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          Text(
            '${_currentIndex + 1}',
            style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold),
          ),
          Text(
            ' / ${_sentences.length}',
            style: TextStyle(color: colorScheme.outline),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (_currentIndex + 1) / _sentences.length,
                backgroundColor: colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                minHeight: 4,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // 播放次数
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.replay, size: 14, color: colorScheme.outline),
                const SizedBox(width: 4),
                Text(
                  '$_playCount',
                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayControl() {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // 大播放按钮
        GestureDetector(
          onTap: _isAudioLoading ? null : (_isPlaying ? _stopPlaying : _playSentence),
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isAudioLoading
                    ? [Colors.grey[400]!, Colors.grey[600]!]
                    : _isPlaying
                        ? [Colors.red[400]!, Colors.red[600]!]
                        : [colorScheme.primary, colorScheme.primaryContainer],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (_isAudioLoading ? Colors.grey : _isPlaying ? Colors.red : colorScheme.primary).withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: _isAudioLoading
                ? const SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  )
                : Icon(
                    _isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                    size: 50,
                    color: Colors.white,
                  ),
          ),
        ),

        const SizedBox(height: 16),

        // 音频进度条（仅在线音频显示）
        if (_useRealAudio && (_isPlaying || _position > Duration.zero)) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                SliderTheme(
                  data: const SliderThemeData(
                    trackHeight: 4,
                    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
                  ),
                  child: Slider(
                    value: _duration.inMilliseconds > 0
                        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
                        : 0.0,
                    activeColor: colorScheme.primary,
                    inactiveColor: colorScheme.surfaceContainerHighest,
                    onChanged: (v) {
                      if (_duration.inMilliseconds > 0) {
                        final newPosition = Duration(milliseconds: (v * _duration.inMilliseconds).round());
                        UnifiedAudioService.instance.seek(newPosition);
                      }
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(_position),
                      style: TextStyle(color: colorScheme.outline, fontSize: 11),
                    ),
                    Text(
                      _formatDuration(_duration),
                      style: TextStyle(color: colorScheme.outline, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],

        // 语速控制 - 8档快速选择按钮 (参考可可英语)
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 4,
          runSpacing: 4,
          children: [
            _buildSpeedButton(0.5, '0.5x'),
            _buildSpeedButton(0.6, '0.6x'),
            _buildSpeedButton(0.75, '0.75x'),
            _buildSpeedButton(0.85, '0.85x'),
            _buildSpeedButton(1.0, '1.0x'),
            _buildSpeedButton(1.15, '1.15x'),
            _buildSpeedButton(1.25, '1.25x'),
            _buildSpeedButton(1.5, '1.5x'),
          ],
        ),

        const SizedBox(height: 12),

        // 语速微调滑块
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.slow_motion_video, size: 16, color: colorScheme.outline),
            const SizedBox(width: 8),
            SizedBox(
              width: 150,
              child: Slider(
                value: _speechRate,
                min: 0.2,
                max: 1.0,
                divisions: 16,
                activeColor: colorScheme.primary,
                inactiveColor: colorScheme.surfaceContainerHighest,
                onChanged: (v) {
                  setState(() => _speechRate = v);
                  ListeningSettingsService.instance.setSpeechRate(v);
                },
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${(_speechRate * 2).toStringAsFixed(2)}x',
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ),

        // 循环模式控制 - 4种模式 (参考每日英语听力)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 循环模式切换按钮
            TextButton.icon(
              onPressed: _toggleLoopMode,
              icon: Icon(
                _getLoopModeIcon(),
                size: 18,
                color: _loopModeIndex > 0 ? colorScheme.primary : colorScheme.outline,
              ),
              label: Text(
                _getLoopModeLabel(),
                style: TextStyle(
                  color: _loopModeIndex > 0 ? colorScheme.primary : colorScheme.outline,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 16),
            TextButton.icon(
              onPressed: _delayedReplay,
              icon: Icon(
                Icons.timer,
                size: 18,
                color: colorScheme.outline,
              ),
              label: Text(
                '3秒后重播',
                style: TextStyle(
                  color: colorScheme.outline,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSentenceCard() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 英文原文标题栏
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'English',
                  style: TextStyle(color: colorScheme.onPrimaryContainer, fontSize: 11),
                ),
              ),
              const SizedBox(width: 8),
              // 收藏按钮
              GestureDetector(
                onTap: _toggleCollect,
                child: Icon(
                  _isCurrentCollected ? Icons.favorite : Icons.favorite_border,
                  size: 18,
                  color: _isCurrentCollected ? Colors.red : colorScheme.outline,
                ),
              ),
              const SizedBox(width: 8),
              // 难句标记
              GestureDetector(
                onTap: _toggleDifficult,
                child: Icon(
                  _isCurrentDifficult ? Icons.flag : Icons.flag_outlined,
                  size: 18,
                  color: _isCurrentDifficult ? Colors.orange : colorScheme.outline,
                ),
              ),
              const Spacer(),
              if (!_showEnglish && !_isDictationMode)
                Text(
                  '点击单词查释义',
                  style: TextStyle(color: colorScheme.outline, fontSize: 11),
                ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedCrossFade(
            firstChild: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '••••••••••••••••••••',
                style: TextStyle(
                  color: colorScheme.outline,
                  fontSize: 18,
                  letterSpacing: 2,
                ),
              ),
            ),
            secondChild: _buildHighlightedText(),
            crossFadeState: _showEnglish || _showDictationResult
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),

          const SizedBox(height: 24),

          // 中文翻译
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '中文',
                  style: TextStyle(color: colorScheme.onSecondaryContainer, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedCrossFade(
            firstChild: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '••••••••••••••••',
                style: TextStyle(
                  color: colorScheme.outline,
                  fontSize: 16,
                  letterSpacing: 2,
                ),
              ),
            ),
            secondChild: Text(
              _chineseText.isEmpty ? '(无翻译)' : _chineseText,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 16,
                height: 1.5,
              ),
            ),
            crossFadeState: _showChinese || _showDictationResult
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  /// 构建带高亮和点词查询的文本
  Widget _buildHighlightedText() {
    final colorScheme = Theme.of(context).colorScheme;
    final words = _englishText.split(RegExp(r'(\s+)'));
    int wordIndex = 0;

    return Wrap(
      spacing: 4,
      runSpacing: 8,
      children: words.map((segment) {
        // 如果是空白字符，直接返回
        if (segment.trim().isEmpty) {
          return Text(segment, style: const TextStyle(fontSize: 18));
        }

        final currentWordIndex = wordIndex;
        wordIndex++;

        final isHighlighted = currentWordIndex == _highlightedWordIndex;

        return GestureDetector(
          onTap: () {
            // 获取点击位置用于弹窗
            final RenderBox? box = context.findRenderObject() as RenderBox?;
            if (box != null) {
              final position = box.localToGlobal(Offset.zero);
              _showWordLookup(segment, Offset(
                position.dx + 100,
                position.dy + 200,
              ));
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            decoration: BoxDecoration(
              color: isHighlighted ? colorScheme.primary.withValues(alpha: 0.3) : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: isHighlighted ? Border.all(color: colorScheme.primary, width: 1) : null,
            ),
            child: Text(
              segment,
              style: TextStyle(
                color: isHighlighted ? colorScheme.primary : colorScheme.onSurface,
                fontSize: 18,
                height: 1.6,
                fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildShowControls() {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ControlChip(
              label: '显示原文',
              icon: Icons.text_fields,
              isActive: _showEnglish,
              onTap: () => setState(() => _showEnglish = !_showEnglish),
            ),
            const SizedBox(width: 16),
            _ControlChip(
              label: '显示翻译',
              icon: Icons.translate,
              isActive: _showChinese,
              onTap: () => setState(() => _showChinese = !_showChinese),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // AB复读控制
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ControlChip(
              label: _pointA >= 0 ? 'A:${_pointA + 1}' : '设A点',
              icon: Icons.looks_one,
              isActive: _pointA >= 0,
              onTap: _setPointA,
            ),
            const SizedBox(width: 12),
            _ControlChip(
              label: _pointB >= 0 ? 'B:${_pointB + 1}' : '设B点',
              icon: Icons.looks_two,
              isActive: _pointB >= 0,
              onTap: _setPointB,
            ),
            if (_isABRepeatMode) ...[
              const SizedBox(width: 12),
              _ControlChip(
                label: '清除AB',
                icon: Icons.clear,
                isActive: false,
                onTap: _clearABRepeat,
              ),
            ],
          ],
        ),
        if (_isABRepeatMode)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'AB复读中: 第${_pointA + 1}句 - 第${_pointB + 1}句',
              style: TextStyle(color: colorScheme.primary, fontSize: 12),
            ),
          ),
        const SizedBox(height: 16),
        // 跟读打分
        _buildPronunciationSection(),
      ],
    );
  }

  /// 构建跟读打分区域
  Widget _buildPronunciationSection() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        // 跟读按钮
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: _speechAvailable
                  ? (_isListening ? _stopListening : _startListening)
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  gradient: _isListening
                      ? LinearGradient(
                          colors: [Colors.red[400]!, Colors.red[600]!],
                        )
                      : LinearGradient(
                          colors: [colorScheme.primary, colorScheme.primaryContainer],
                        ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: (_isListening ? Colors.red : colorScheme.primary).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isListening ? Icons.stop : Icons.mic,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isListening ? '停止录音' : '跟读打分',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_showPronunciationResult) ...[
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _resetPronunciationResult,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.refresh, size: 18, color: colorScheme.onSurface),
                ),
              ),
            ],
          ],
        ),

        // 录音中提示
        if (_isListening) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '正在录音，请朗读句子...',
                style: TextStyle(color: colorScheme.error, fontSize: 13),
              ),
            ],
          ),
          if (_recognizedText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _recognizedText,
                style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],

        // 打分结果
        if (_showPronunciationResult && !_isListening) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _pronunciationScore >= 80
                    ? Colors.green
                    : _pronunciationScore >= 60
                        ? Colors.orange
                        : Colors.red,
                width: 2,
              ),
            ),
            child: Column(
              children: [
                // 分数显示
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _pronunciationScore >= 80
                          ? Icons.emoji_events
                          : _pronunciationScore >= 60
                              ? Icons.thumb_up
                              : Icons.refresh,
                      color: _pronunciationScore >= 80
                          ? Colors.amber
                          : _pronunciationScore >= 60
                              ? Colors.orange
                              : Colors.grey,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${_pronunciationScore.toStringAsFixed(0)}分',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: _pronunciationScore >= 80
                            ? Colors.green
                            : _pronunciationScore >= 60
                                ? Colors.orange
                                : Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _pronunciationScore >= 80
                      ? '发音很棒！'
                      : _pronunciationScore >= 60
                          ? '继续加油！'
                          : '再练习一下',
                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
                ),
                if (_recognizedText.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '识别结果:',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _recognizedText,
                          style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],

        // 语音不可用提示
        if (!_speechAvailable)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '语音识别不可用',
              style: TextStyle(color: colorScheme.outline, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildDictationArea() {
    final colorScheme = Theme.of(context).colorScheme;
    final accuracy = _showDictationResult ? _getDictationAccuracy() : 0.0;

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _showDictationResult
                  ? (accuracy > 0.8 ? Colors.green : Colors.orange)
                  : colorScheme.outline,
            ),
          ),
          child: TextField(
            controller: _dictationController,
            maxLines: 4,
            style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
            decoration: InputDecoration(
              hintText: '听写内容...',
              hintStyle: TextStyle(color: colorScheme.outline),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
            enabled: !_showDictationResult,
          ),
        ),
        const SizedBox(height: 16),
        if (_showDictationResult)
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accuracy > 0.8 ? Colors.green[900] : Colors.orange[900],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      accuracy > 0.8 ? Icons.check_circle : Icons.info,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '正确率: ${(accuracy * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // 再来一次按钮
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _showDictationResult = false;
                    _dictationController.clear();
                    _dictationAnalysis = null;
                  });
                },
                icon: const Icon(Icons.refresh),
                label: const Text('再来一次'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ],
          )
        else
          ElevatedButton(
            onPressed: _checkDictation,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
            child: const Text('检查答案'),
          ),
      ],
    );
  }

  Widget _buildBottomControls() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 上一句
          IconButton(
            onPressed: _currentIndex > 0 ? _prevSentence : null,
            icon: Icon(
              Icons.skip_previous_rounded,
              color: _currentIndex > 0 ? colorScheme.onSurface : colorScheme.outline,
              size: 32,
            ),
          ),
          // 重播
          IconButton(
            onPressed: _playSentence,
            icon: Icon(Icons.replay, color: colorScheme.primary, size: 28),
          ),
          // 下一句
          IconButton(
            onPressed: _currentIndex < _sentences.length - 1 ? _nextSentence : null,
            icon: Icon(
              Icons.skip_next_rounded,
              color: _currentIndex < _sentences.length - 1 ? colorScheme.onSurface : colorScheme.outline,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '听力设置',
                style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              // 语速设置
              Row(
                children: [
                  Text('语速', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                  const Spacer(),
                  Text(
                    '${(_speechRate * 2).toStringAsFixed(1)}x',
                    style: TextStyle(color: colorScheme.primary),
                  ),
                ],
              ),
              Slider(
                value: _speechRate,
                min: 0.2,
                max: 1.0,
                divisions: 8,
                activeColor: colorScheme.primary,
                inactiveColor: colorScheme.surfaceContainerHighest,
                onChanged: (v) {
                  setState(() => _speechRate = v);
                  setModalState(() {});
                  ListeningSettingsService.instance.setSpeechRate(v);
                },
              ),
              const SizedBox(height: 8),
              // 单句循环
              SwitchListTile(
                title: Text('单句循环', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                subtitle: Text('播放完自动重复', style: TextStyle(color: colorScheme.outline, fontSize: 12)),
                value: _isLoopMode,
                activeColor: colorScheme.primary,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) {
                  setState(() {
                    _isLoopMode = v;
                    if (v) _isAutoNextMode = false; // 互斥
                  });
                  setModalState(() {});
                  ListeningSettingsService.instance.setLoopMode(v);
                  if (v) ListeningSettingsService.instance.setAutoNext(false);
                },
              ),
              // 自动下一句
              SwitchListTile(
                title: Text('自动下一句', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                subtitle: Text('播放完自动播放下一句', style: TextStyle(color: colorScheme.outline, fontSize: 12)),
                value: _isAutoNextMode,
                activeColor: colorScheme.primary,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) {
                  setState(() {
                    _isAutoNextMode = v;
                    if (v) _isLoopMode = false; // 互斥
                  });
                  setModalState(() {});
                  ListeningSettingsService.instance.setAutoNext(v);
                  if (v) ListeningSettingsService.instance.setLoopMode(false);
                },
              ),
              // 自动下一句延迟
              if (_isAutoNextMode) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('延迟时间', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                    const Spacer(),
                    Text(
                      '$_autoNextDelay 秒',
                      style: TextStyle(color: colorScheme.primary),
                    ),
                  ],
                ),
                Slider(
                  value: _autoNextDelay.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  activeColor: colorScheme.primary,
                  inactiveColor: colorScheme.surfaceContainerHighest,
                  onChanged: (v) {
                    setState(() => _autoNextDelay = v.toInt());
                    setModalState(() {});
                    ListeningSettingsService.instance.setAutoNextDelay(v.toInt());
                  },
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _ControlChip({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? colorScheme.primary.withValues(alpha: 0.2) : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? colorScheme.primary : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isActive ? colorScheme.primary : colorScheme.outline),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 导入听力素材对话框
class _ImportListeningDialog extends StatefulWidget {
  final String bookId;

  const _ImportListeningDialog({required this.bookId});

  @override
  State<_ImportListeningDialog> createState() => _ImportListeningDialogState();
}

class _ImportListeningDialogState extends State<_ImportListeningDialog> {
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  bool _isImporting = false;
  int _importMode = 0; // 0: 文件, 1: 网络, 2: 粘贴

  @override
  void dispose() {
    _textController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _importFromUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入URL地址')),
      );
      return;
    }

    // 验证URL格式
    Uri? uri;
    try {
      uri = Uri.parse(url);
      if (!uri.hasScheme || (!uri.scheme.startsWith('http'))) {
        throw const FormatException('Invalid URL scheme');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效的URL地址')),
      );
      return;
    }

    setState(() => _isImporting = true);

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final content = response.body;

        final importResult = await ImportService.instance.importListeningMaterials(
          widget.bookId,
          content,
        );

        if (mounted) {
          Navigator.pop(context, importResult);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('下载失败: HTTP ${response.statusCode}')),
          );
          setState(() => _isImporting = false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载失败: $e')),
        );
        setState(() => _isImporting = false);
      }
    }
  }

  Future<void> _importFromFile() async {
    try {
      const XTypeGroup typeGroup = XTypeGroup(
        label: '听力素材',
        extensions: ['json', 'txt'],
      );

      final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);

      if (file != null) {
        setState(() => _isImporting = true);

        final content = await file.readAsString();

        final importResult = await ImportService.instance.importListeningMaterials(
          widget.bookId,
          content,
        );

        if (mounted) {
          Navigator.pop(context, importResult);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e')),
        );
        setState(() => _isImporting = false);
      }
    }
  }

  Future<void> _importFromText() async {
    final content = _textController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入内容')),
      );
      return;
    }

    setState(() => _isImporting = true);

    final result = await ImportService.instance.importListeningMaterials(
      widget.bookId,
      content,
    );

    if (mounted) {
      Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 520,
        constraints: const BoxConstraints(maxHeight: 600),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.file_upload, color: Color(0xFF3C8CE7)),
                  const SizedBox(width: 12),
                  const Text(
                    '导入听力素材',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 导入方式选择
              Row(
                children: [
                  _buildModeChip(0, Icons.folder_open, '本地文件'),
                  const SizedBox(width: 8),
                  _buildModeChip(1, Icons.cloud_download, '网络下载'),
                  const SizedBox(width: 8),
                  _buildModeChip(2, Icons.paste, '粘贴文本'),
                ],
              ),
              const SizedBox(height: 16),

              // 格式说明
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('支持的格式:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    Text(
                      'JSON: {"sentences": [{"en": "Hello", "cn": "你好"}]}\n'
                      '纯文本: 英文句子\\n中文翻译 (每两行一组)',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 根据模式显示不同内容
              if (_importMode == 0) ...[
                // 从文件导入
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isImporting ? null : _importFromFile,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('选择文件 (JSON/TXT)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3C8CE7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ] else if (_importMode == 1) ...[
                // 从URL下载
                TextField(
                  controller: _urlController,
                  decoration: InputDecoration(
                    hintText: 'https://example.com/sentences.json',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                    prefixIcon: const Icon(Icons.link, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isImporting ? null : _importFromUrl,
                    icon: _isImporting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.cloud_download),
                    label: Text(_isImporting ? '下载中...' : '下载并导入'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3C8CE7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ] else ...[
                // 粘贴文本
                TextField(
                  controller: _textController,
                  maxLines: 8,
                  decoration: InputDecoration(
                    hintText: 'Hello, how are you?\n你好，你好吗？\n\nI am fine.\n我很好。',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isImporting ? null : _importFromText,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3C8CE7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isImporting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('导入'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeChip(int mode, IconData icon, String label) {
    final isSelected = _importMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _importMode = mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF3C8CE7) : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFF3C8CE7) : Colors.grey[300]!,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: isSelected ? Colors.white : Colors.grey[600]),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected ? Colors.white : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 听写单词分析结果
class DictationWord {
  final String word;
  final bool isCorrect;
  final String? userInput;

  DictationWord({
    required this.word,
    required this.isCorrect,
    this.userInput,
  });
}

/// 查词弹窗
class _WordLookupPopup extends StatefulWidget {
  final String word;
  final Offset position;
  final VoidCallback onClose;

  const _WordLookupPopup({
    required this.word,
    required this.position,
    required this.onClose,
  });

  @override
  State<_WordLookupPopup> createState() => _WordLookupPopupState();
}

class _WordLookupPopupState extends State<_WordLookupPopup> {
  WordDefinition? _definition;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _lookupWord();
  }

  Future<void> _lookupWord() async {
    try {
      final result = await TranslationService.instance.lookupWord(widget.word);
      if (mounted) {
        setState(() {
          _definition = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '查询失败';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenSize = MediaQuery.of(context).size;

    // 计算弹窗位置，确保不超出屏幕
    double left = widget.position.dx;
    double top = widget.position.dy;

    const popupWidth = 320.0;
    const popupHeight = 200.0;

    if (left + popupWidth > screenSize.width) {
      left = screenSize.width - popupWidth - 16;
    }
    if (top + popupHeight > screenSize.height) {
      top = screenSize.height - popupHeight - 16;
    }

    return Stack(
      children: [
        // 背景遮罩
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            child: Container(color: Colors.black26),
          ),
        ),
        // 弹窗内容
        Positioned(
          left: left.clamp(16.0, screenSize.width - popupWidth - 16),
          top: top.clamp(100.0, screenSize.height - popupHeight - 16),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: colorScheme.surfaceContainer,
            child: Container(
              width: popupWidth,
              constraints: const BoxConstraints(maxHeight: 280),
              padding: const EdgeInsets.all(16),
              child: _isLoading
                  ? Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.primary,
                        ),
                      ),
                    )
                  : _error != null
                      ? Center(
                          child: Text(
                            _error!,
                            style: TextStyle(color: colorScheme.outline),
                          ),
                        )
                      : SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 单词和音标
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _definition?.word ?? widget.word,
                                      style: TextStyle(
                                        color: colorScheme.onSurface,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 18),
                                    color: colorScheme.outline,
                                    onPressed: widget.onClose,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                              if (_definition?.phoneticUs != null && _definition!.phoneticUs.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'US: ${_definition!.phoneticUs}',
                                    style: TextStyle(
                                      color: colorScheme.outline,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 12),
                              // 释义
                              if (_definition?.translation != null && _definition!.translation.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _definition!.translation,
                                    style: TextStyle(
                                      color: colorScheme.primary,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              if (_definition?.definitions.isNotEmpty == true) ...[
                                const SizedBox(height: 8),
                                ...(_definition!.definitions.take(3).map((def) => Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '• $def',
                                    style: TextStyle(
                                      color: colorScheme.onSurfaceVariant,
                                      fontSize: 13,
                                    ),
                                  ),
                                ))),
                              ],
                            ],
                          ),
                        ),
            ),
          ),
        ),
      ],
    );
  }
}
