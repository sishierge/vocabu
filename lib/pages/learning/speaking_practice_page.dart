import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../services/tts_service.dart';
import '../../services/custom_materials_service.dart';
import '../../services/listening_materials_service.dart';
import '../../services/speaking_practice_service.dart';

/// 口语练习页面 - 专项跟读打分
class SpeakingPracticePage extends StatefulWidget {
  const SpeakingPracticePage({super.key});

  @override
  State<SpeakingPracticePage> createState() => _SpeakingPracticePageState();
}

class _SpeakingPracticePageState extends State<SpeakingPracticePage> {
  // 句子列表
  List<Map<String, String>> _sentences = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  String? _currentMaterialName;

  // 语音识别
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;
  String _recognizedText = '';

  // 练习状态
  bool _showResult = false;
  double _currentScore = 0;
  List<WordScore> _wordScores = [];

  // 练习统计
  int _totalPracticed = 0;
  double _averageScore = 0;

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  Future<void> _initServices() async {
    await SpeakingPracticeService.instance.initialize();
    await CustomMaterialsService.instance.initialize();
    await _initSpeechRecognition();
    _loadDefaultSentences();
  }

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
              _calculateScore();
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
    } catch (e) {
      _speechAvailable = false;
    }
  }

  void _loadDefaultSentences() {
    // 加载内置口语练习句子
    _sentences = SpeakingPracticeService.builtInSentences;
    _currentMaterialName = '日常口语';
    setState(() => _isLoading = false);
  }

  /// 加载在线对话素材
  Future<void> _loadOnlineDialogues() async {
    setState(() => _isLoading = true);
    try {
      final dialogues = await SpeakingPracticeService.instance.fetchOnlineDialogues(count: 100);
      if (dialogues.isNotEmpty && mounted) {
        setState(() {
          _sentences = dialogues;
          _currentMaterialName = '在线对话';
          _currentIndex = 0;
          _isLoading = false;
          _showResult = false;
        });
      } else {
        if (mounted) {
          _showErrorSnackBar('获取在线对话失败，请稍后重试');
        }
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('网络错误，请稍后重试');
      }
      setState(() => _isLoading = false);
    }
  }

  /// 加载混合素材（本地+在线）
  Future<void> _loadMixedSentences() async {
    setState(() => _isLoading = true);
    try {
      final sentences = await SpeakingPracticeService.instance.getMixedSentences(
        count: 50,
        includeOnline: true,
      );
      if (sentences.isNotEmpty && mounted) {
        setState(() {
          _sentences = sentences;
          _currentMaterialName = '混合练习';
          _currentIndex = 0;
          _isLoading = false;
          _showResult = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  String get _englishText =>
      _sentences.isNotEmpty && _currentIndex < _sentences.length
          ? _sentences[_currentIndex]['en'] ?? ''
          : '';

  String get _chineseText =>
      _sentences.isNotEmpty && _currentIndex < _sentences.length
          ? _sentences[_currentIndex]['cn'] ?? ''
          : '';

  /// 播放示范发音
  Future<void> _playExample() async {
    if (_englishText.isEmpty) return;
    await TtsService.instance.speak(_englishText);
  }

  /// 开始录音
  Future<void> _startListening() async {
    if (!_speechAvailable) {
      _showErrorSnackBar('语音识别不可用，请检查麦克风权限');
      return;
    }

    // 停止播放
    await TtsService.instance.stop();

    setState(() {
      _isListening = true;
      _recognizedText = '';
      _showResult = false;
      _wordScores = [];
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

  /// 停止录音
  Future<void> _stopListening() async {
    await _speech.stop();
    if (mounted) {
      setState(() => _isListening = false);
      _calculateScore();
    }
  }

  /// 计算发音得分
  void _calculateScore() {
    if (_recognizedText.isEmpty || _englishText.isEmpty) {
      setState(() {
        _currentScore = 0;
        _showResult = true;
        _wordScores = [];
      });
      return;
    }

    final targetWords = _normalizeText(_englishText).split(RegExp(r'\s+'));
    final spokenWords = _normalizeText(_recognizedText).split(RegExp(r'\s+'));

    // 分析每个单词
    _wordScores = [];
    final spokenSet = spokenWords.toSet();

    for (final word in targetWords) {
      final isCorrect = spokenSet.contains(word);
      _wordScores.add(WordScore(word: word, isCorrect: isCorrect));
    }

    // 计算得分
    final correctCount = _wordScores.where((w) => w.isCorrect).length;
    double baseScore = (correctCount / targetWords.length) * 100;

    // 顺序加分
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

    final finalScore = (baseScore + orderScore).clamp(0.0, 100.0);

    setState(() {
      _currentScore = finalScore;
      _showResult = true;
      _totalPracticed++;
      _averageScore = ((_averageScore * (_totalPracticed - 1)) + finalScore) / _totalPracticed;
    });

    // 保存练习记录
    SpeakingPracticeService.instance.addPracticeRecord(
      sentence: _englishText,
      score: finalScore,
    );
  }

  String _normalizeText(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z0-9\s']"), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  void _nextSentence() {
    if (_currentIndex < _sentences.length - 1) {
      setState(() {
        _currentIndex++;
        _showResult = false;
        _recognizedText = '';
        _wordScores = [];
      });
    }
  }

  void _prevSentence() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _showResult = false;
        _recognizedText = '';
        _wordScores = [];
      });
    }
  }

  void _retryPractice() {
    setState(() {
      _showResult = false;
      _recognizedText = '';
      _wordScores = [];
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red[700]),
    );
  }

  /// 显示素材选择器
  void _showMaterialPicker() {
    final colorScheme = Theme.of(context).colorScheme;
    final customMaterials = CustomMaterialsService.instance.materials;
    final onlineCount = SpeakingPracticeService.instance.onlineDialogueCount;

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
        maxChildSize: 0.85,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.record_voice_over, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Text(
                    '选择练习素材',
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
                  // 在线素材 - 新增
                  _buildMaterialCategory('在线素材', Icons.cloud_download, [
                    _MaterialOption(
                      name: '在线对话 (DailyDialog)',
                      count: onlineCount > 0 ? onlineCount : null,
                      subtitle: onlineCount > 0 ? '$onlineCount 句已缓存' : '点击获取 11000+ 英语对话',
                      isSelected: _currentMaterialName == '在线对话',
                      onTap: () {
                        Navigator.pop(context);
                        _loadOnlineDialogues();
                      },
                    ),
                    _MaterialOption(
                      name: '混合练习',
                      subtitle: '本地 + 在线素材随机混合',
                      isSelected: _currentMaterialName == '混合练习',
                      onTap: () {
                        Navigator.pop(context);
                        _loadMixedSentences();
                      },
                    ),
                  ]),

                  const SizedBox(height: 16),

                  // 内置素材
                  _buildMaterialCategory('内置素材', Icons.library_books, [
                    _MaterialOption(
                      name: '日常口语',
                      count: SpeakingPracticeService.builtInSentences.length,
                      isSelected: _currentMaterialName == '日常口语',
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          _sentences = SpeakingPracticeService.builtInSentences;
                          _currentMaterialName = '日常口语';
                          _currentIndex = 0;
                          _showResult = false;
                        });
                      },
                    ),
                    ...ListeningMaterialsService.sources.take(5).map((source) =>
                      _MaterialOption(
                        name: source.name,
                        count: source.sentenceCount,
                        isSelected: _currentMaterialName == source.name,
                        onTap: () async {
                          Navigator.pop(context);
                          await _loadFromMaterialSource(source);
                        },
                      ),
                    ),
                  ]),

                  if (customMaterials.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildMaterialCategory('我的素材', Icons.folder, [
                      ...customMaterials.map((material) =>
                        _MaterialOption(
                          name: material.name,
                          count: material.sentenceCount,
                          isSelected: _currentMaterialName == material.name,
                          onTap: () {
                            Navigator.pop(context);
                            _loadCustomMaterial(material);
                          },
                        ),
                      ),
                    ]),
                  ],

                  // 刷新在线数据按钮
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      setState(() => _isLoading = true);
                      await SpeakingPracticeService.instance.refreshOnlineDialogues();
                      if (mounted) {
                        setState(() => _isLoading = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('在线素材已刷新')),
                        );
                      }
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('刷新在线素材'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialCategory(String title, IconData icon, List<Widget> items) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: colorScheme.primary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...items,
      ],
    );
  }

  Future<void> _loadFromMaterialSource(MaterialSource source) async {
    setState(() => _isLoading = true);

    try {
      final sentences = await ListeningMaterialsService.instance.fetchMaterialContent(source.id);
      if (sentences.isNotEmpty && mounted) {
        setState(() {
          _sentences = sentences;
          _currentMaterialName = source.name;
          _currentIndex = 0;
          _isLoading = false;
          _showResult = false;
        });
      } else {
        if (mounted) {
          _showErrorSnackBar('加载素材失败');
        }
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('加载失败，请稍后重试');
      }
      setState(() => _isLoading = false);
    }
  }

  void _loadCustomMaterial(CustomMaterial material) {
    final sentences = CustomMaterialsService.instance.getMaterialSentences(material.id);
    if (sentences.isNotEmpty) {
      setState(() {
        _sentences = sentences;
        _currentMaterialName = material.name;
        _currentIndex = 0;
        _showResult = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _currentMaterialName ?? '口语练习',
          style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
        ),
        actions: [
          // 练习统计
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.bar_chart, size: 16, color: colorScheme.primary),
                const SizedBox(width: 4),
                Text(
                  '$_totalPracticed 句 | ${_averageScore.toStringAsFixed(0)}分',
                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.library_music, color: colorScheme.primary),
            onPressed: _showMaterialPicker,
            tooltip: '选择素材',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
          : _sentences.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    // 进度条
                    _buildProgressBar(),

                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            // 目标句子卡片
                            _buildTargetCard(),

                            const SizedBox(height: 24),

                            // 录音控制区
                            _buildRecordingArea(),

                            const SizedBox(height: 24),

                            // 结果显示
                            if (_showResult) _buildResultCard(),
                          ],
                        ),
                      ),
                    ),

                    // 底部导航
                    _buildBottomNav(),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.record_voice_over_outlined, size: 64, color: colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            '暂无练习素材',
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showMaterialPicker,
            icon: const Icon(Icons.library_music),
            label: const Text('选择素材'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          Text(
            '${_currentIndex + 1}',
            style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Text(
            ' / ${_sentences.length}',
            style: TextStyle(color: colorScheme.outline, fontSize: 16),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (_currentIndex + 1) / _sentences.length,
                backgroundColor: colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                minHeight: 6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetCard() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '跟读句子',
                  style: TextStyle(
                    color: colorScheme.onPrimaryContainer,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.volume_up, color: colorScheme.primary),
                onPressed: _playExample,
                tooltip: '播放示范',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _englishText,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 20,
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _chineseText,
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingArea() {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // 录音按钮
        GestureDetector(
          onTap: _speechAvailable
              ? (_isListening ? _stopListening : _startListening)
              : null,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isListening
                    ? [Colors.red[400]!, Colors.red[600]!]
                    : _speechAvailable
                        ? [colorScheme.primary, colorScheme.primaryContainer]
                        : [Colors.grey[400]!, Colors.grey[600]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (_isListening ? Colors.red : colorScheme.primary).withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              _isListening ? Icons.stop_rounded : Icons.mic_rounded,
              size: 45,
              color: Colors.white,
            ),
          ),
        ),

        const SizedBox(height: 16),

        Text(
          _isListening ? '正在录音，请朗读...' : '点击开始录音',
          style: TextStyle(
            color: _isListening ? colorScheme.error : colorScheme.onSurfaceVariant,
            fontSize: 14,
          ),
        ),

        // 实时识别文本
        if (_isListening && _recognizedText.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _recognizedText,
              style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ],

        if (!_speechAvailable)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '语音识别不可用',
              style: TextStyle(color: colorScheme.error, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildResultCard() {
    final colorScheme = Theme.of(context).colorScheme;
    final isGood = _currentScore >= 80;
    final isOkay = _currentScore >= 60;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGood ? Colors.green : isOkay ? Colors.orange : Colors.red,
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
                isGood ? Icons.emoji_events : isOkay ? Icons.thumb_up : Icons.refresh,
                color: isGood ? Colors.amber : isOkay ? Colors.orange : Colors.grey,
                size: 36,
              ),
              const SizedBox(width: 16),
              Text(
                _currentScore.toStringAsFixed(0),
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: isGood ? Colors.green : isOkay ? Colors.orange : Colors.red,
                ),
              ),
              Text(
                '分',
                style: TextStyle(
                  fontSize: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            isGood ? '发音很棒！' : isOkay ? '继续加油！' : '再练习一下',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 16,
            ),
          ),

          // 单词详情
          if (_wordScores.isNotEmpty) ...[
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _wordScores.map((ws) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: ws.isCorrect
                      ? Colors.green.withValues(alpha: 0.15)
                      : Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: ws.isCorrect ? Colors.green : Colors.red,
                  ),
                ),
                child: Text(
                  ws.word,
                  style: TextStyle(
                    color: ws.isCorrect ? Colors.green[700] : Colors.red[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )).toList(),
            ),
          ],

          const SizedBox(height: 24),

          // 操作按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _retryPractice,
                icon: const Icon(Icons.refresh),
                label: const Text('再试一次'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _currentIndex < _sentences.length - 1 ? _nextSentence : null,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('下一句'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
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
          IconButton(
            onPressed: _currentIndex > 0 ? _prevSentence : null,
            icon: Icon(
              Icons.skip_previous_rounded,
              color: _currentIndex > 0 ? colorScheme.onSurface : colorScheme.outline,
              size: 32,
            ),
          ),
          IconButton(
            onPressed: _playExample,
            icon: Icon(Icons.volume_up, color: colorScheme.primary, size: 28),
            tooltip: '播放示范',
          ),
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
}

/// 素材选项组件
class _MaterialOption extends StatelessWidget {
  final String name;
  final int? count;
  final String? subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _MaterialOption({
    required this.name,
    this.count,
    this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? colorScheme.primary.withValues(alpha: 0.15) : colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: isSelected ? Border.all(color: colorScheme.primary) : null,
      ),
      child: ListTile(
        title: Text(
          name,
          style: TextStyle(
            color: isSelected ? colorScheme.primary : colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Text(
          subtitle ?? (count != null ? '$count 句' : ''),
          style: TextStyle(color: colorScheme.outline, fontSize: 12),
        ),
        trailing: isSelected
            ? Icon(Icons.check_circle, color: colorScheme.primary)
            : Icon(Icons.play_circle_outline, color: colorScheme.outline),
        onTap: onTap,
      ),
    );
  }
}

/// 单词得分
class WordScore {
  final String word;
  final bool isCorrect;

  WordScore({required this.word, required this.isCorrect});
}
