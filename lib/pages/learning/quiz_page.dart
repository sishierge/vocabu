import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../providers/word_book_provider.dart';
import '../../services/algorithm_scheduler.dart';
import '../../services/tts_service.dart';
import '../../services/learning_stats_service.dart';

class QuizPage extends StatefulWidget {
  final String? bookId;
  final String? bookName;

  const QuizPage({super.key, this.bookId, this.bookName});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  List<Map<String, dynamic>> _words = [];
  List<Map<String, dynamic>> _allWords = []; // For generating wrong options
  int _currentIndex = 0;
  int _correctCount = 0;
  int? _selectedOption;
  bool _showResult = false;
  bool _isLoading = true;
  List<String> _cachedOptions = []; // 缓存当前题目的选项
  int _correctOptionIndex = -1;     // 正确答案的索引
  bool _isProcessing = false;       // 防止重复点击
  final AlgorithmScheduler _scheduler = AlgorithmScheduler.instance;
  final FocusNode _focusNode = FocusNode();


  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  /// 处理键盘事件
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (_isLoading || _words.isEmpty || _showResult || _isProcessing) {
      return KeyEventResult.ignored;
    }

    // 数字键 1-4 选择选项 A-D
    if (event.logicalKey == LogicalKeyboardKey.digit1 ||
        event.logicalKey == LogicalKeyboardKey.numpad1) {
      _selectOption(0);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.digit2 ||
        event.logicalKey == LogicalKeyboardKey.numpad2) {
      _selectOption(1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.digit3 ||
        event.logicalKey == LogicalKeyboardKey.numpad3) {
      _selectOption(2);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.digit4 ||
        event.logicalKey == LogicalKeyboardKey.numpad4) {
      _selectOption(3);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  Future<void> _loadWords() async {
    setState(() => _isLoading = true);
    
    final provider = WordBookProvider.instance;
    final bookId = widget.bookId ?? provider.books.firstOrNull?.bookId;
    
    if (bookId != null) {
      // Load all words for generating options
      _allWords = await provider.getWordsForBook(bookId, limit: 500);
      
      // Load words for quiz (review + new)
      final reviewWords = await provider.getWordsForReview(bookId, limit: 30);
      final newWords = await provider.getWordsForBook(bookId, status: 0, limit: 20);
      
      setState(() {
        _words = [...reviewWords, ...newWords];
        _words.shuffle();
        _isLoading = false;
      });
      
      // 生成第一题的选项
      _generateOptionsForCurrentWord();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic>? get _currentWord => 
      _words.isNotEmpty && _currentIndex < _words.length ? _words[_currentIndex] : null;

  /// 为当前单词生成并缓存选项
  void _generateOptionsForCurrentWord() {
    if (_currentWord == null) {
      _cachedOptions = [];
      _correctOptionIndex = -1;
      return;
    }
    
    final correctTranslate = _currentWord!['Translate'] as String? ?? '(无翻译)';
    final options = <String>[correctTranslate];
    
    // Add 3 wrong options from other words (only those with non-empty translations)
    final otherWords = _allWords.where((w) => 
        w['WordId'] != _currentWord!['WordId'] && 
        (w['Translate'] as String? ?? '').isNotEmpty &&
        (w['Translate'] as String? ?? '') != correctTranslate).toList();
    otherWords.shuffle();
    
    for (var i = 0; i < 3 && i < otherWords.length; i++) {
      final trans = otherWords[i]['Translate'] as String? ?? '';
      if (trans.isNotEmpty) {
        options.add(trans);
      }
    }
    
    // 确保至少有4个选项（填充默认值）
    while (options.length < 4) {
      options.add('(选项 ${options.length + 1})');
    }
    
    // 打乱并缓存
    options.shuffle();
    _cachedOptions = options;
    _correctOptionIndex = _cachedOptions.indexOf(correctTranslate);
    
    // 自动播放当前单词读音
    _playCurrentWord();
  }

  /// 播放当前单词读音
  void _playCurrentWord() {
    if (_currentWord != null) {
      final word = _currentWord!['Word'] as String? ?? '';
      if (word.isNotEmpty) {
        TtsService.instance.speak(word);
      }
    }
  }

  Future<void> _selectOption(int index) async {
    if (!mounted || _showResult || _isProcessing) return;

    setState(() => _isProcessing = true);

    if (kDebugMode) {
      debugPrint('🎯 Quiz: Option $index selected');
    }

    setState(() {
      _selectedOption = index;
      _showResult = true;
    });

    // 使用缓存的正确答案索引
    final isCorrect = index == _correctOptionIndex;

    if (isCorrect) {
      _correctCount++;
      if (kDebugMode) {
        debugPrint('✅ Correct! Total correct: $_correctCount');
      }
    } else {
      if (kDebugMode) {
        debugPrint('❌ Wrong! Correct was: $_correctOptionIndex');
      }
    }

    // Update database based on answer
    final word = _currentWord!;
    final wordId = word['WordId'] as String;
    final wordText = word['Word'] as String? ?? '';
    if (kDebugMode) {
      debugPrint('📝 Updating word: $wordText (ID: $wordId)');
    }

    final learnParam = word['LearnParam'] as String?;

    // Rating: correct = 3 (Good), incorrect = 1 (Again)
    final rating = isCorrect ? 3 : 1;
    final result = _scheduler.schedule(learnParam, rating);

    int newStatus = isCorrect && result.reps >= 3 ? 2 : 1;
    if (kDebugMode) {
      debugPrint('📊 New status: $newStatus, rating: $rating, algorithm: ${_scheduler.algorithmDisplayName}');
    }

    // 异步更新数据库
    WordBookProvider.instance.updateWordStatus(
      wordId,
      newStatus,
      result.learnParam,
      result.nextReview.millisecondsSinceEpoch.toString(),
    ).then((_) {
      if (kDebugMode) {
        debugPrint('💾 Quiz: Database updated for word: $wordText');
      }
    }).catchError((e) {
      if (kDebugMode) {
        debugPrint('❌ Quiz: Database error: $e');
      }
    });

    // 记录学习统计
    final currentStatus = word['LearnStatus'] as int? ?? 0;
    if (currentStatus == 0) {
      LearningStatsService.instance.recordNewWord();
    } else {
      LearningStatsService.instance.recordReview();
    }
    
    // Auto advance after delay - longer delay when wrong to learn the answer
    final delayMs = isCorrect ? 1000 : 2500;
    await Future.delayed(Duration(milliseconds: delayMs));
    
    // Check mounted after async delay
    if (!mounted) return;
    setState(() => _isProcessing = false);
    _nextWord();
  }

  void _nextWord() {
    if (_currentIndex < _words.length - 1) {
      setState(() {
        _selectedOption = null;
        _showResult = false;
        _currentIndex++;
      });
      // 为下一题生成新选项
      _generateOptionsForCurrentWord();
    } else {
      _showSessionComplete();
    }
  }

  void _showSessionComplete() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('测验完成！'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green[400]),
            const SizedBox(height: 16),
            Text('正确率: ${(_correctCount / _words.length * 100).toStringAsFixed(1)}%'),
            Text('正确 $_correctCount / 总共 ${_words.length}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('返回'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _currentIndex = 0;
                _correctCount = 0;
              });
              _loadWords();
            },
            child: const Text('再来一轮'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 使用缓存的选项
    final options = _cachedOptions;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(
            children: [
              const Text('选择练习', style: TextStyle(color: Colors.black, fontSize: 16)),
              const Spacer(),
              if (!_isLoading && _words.isNotEmpty)
                Text('${_currentIndex + 1}/${_words.length}',
                    style: TextStyle(color: Colors.grey[500], fontSize: 14)),
            ],
          ),
          actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.check, size: 16, color: Colors.green[600]),
                const SizedBox(width: 4),
                Text('$_correctCount', style: TextStyle(color: Colors.green[600])),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _words.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, size: 64, color: Colors.green[300]),
                      const SizedBox(height: 16),
                      const Text('暂无需要练习的单词'),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Progress
                    LinearProgressIndicator(
                      value: (_currentIndex + 1) / _words.length,
                      backgroundColor: Colors.grey[200],
                      valueColor: const AlwaysStoppedAnimation(Color(0xFF3C8CE7)),
                    ),
                    const Spacer(),
                    // Word display
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _currentWord!['Word'] as String? ?? '',
                                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.volume_up_rounded, color: Color(0xFF3C8CE7)),
                                onPressed: () {
                                  final word = _currentWord!['Word'] as String? ?? '';
                                  TtsService.instance.speak(word);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _currentWord!['Symbol'] as String? ?? '',
                            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                          ),
                          // Show example when result is displayed
                          if (_showResult && (_currentWord!['Example'] as String? ?? '').isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _currentWord!['Example'] as String? ?? '',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                  fontStyle: FontStyle.italic,
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    // 快捷键提示
                    if (!_showResult)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '快捷键: 1-A  2-B  3-C  4-D',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ),
                    // Options
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: List.generate(options.length, (index) {
                          final isSelected = _selectedOption == index;
                          final isCorrectOption = index == _correctOptionIndex;
                          
                          Color bgColor = Colors.white;
                          Color borderColor = Colors.grey[300]!;
                          
                          if (_showResult) {
                            if (isCorrectOption) {
                              bgColor = Colors.green[50]!;
                              borderColor = Colors.green;
                            } else if (isSelected && !isCorrectOption) {
                              bgColor = Colors.red[50]!;
                              borderColor = Colors.red;
                            }
                          } else if (isSelected) {
                            borderColor = const Color(0xFF3C8CE7);
                          }
                          
                          return GestureDetector(
                            onTap: () => _selectOption(index),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: borderColor, width: 2),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Center(
                                      child: Text(
                                        String.fromCharCode(65 + index),
                                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[600]),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      options[index],
                                      style: const TextStyle(fontSize: 15),
                                    ),
                                  ),
                                  if (_showResult && isCorrectOption)
                                    const Icon(Icons.check_circle, color: Colors.green),
                                  if (_showResult && isSelected && !isCorrectOption)
                                    const Icon(Icons.cancel, color: Colors.red),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const Spacer(),
                    
                    // 底部导航栏
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2)),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // 上一题
                          ElevatedButton.icon(
                            onPressed: _currentIndex > 0 ? () {
                              setState(() {
                                _currentIndex--;
                                _selectedOption = null;
                                _showResult = false;
                              });
                              _generateOptionsForCurrentWord();
                            } : null,
                            icon: const Icon(Icons.arrow_back, size: 18),
                            label: const Text('上一题'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[100],
                              foregroundColor: Colors.black87,
                              elevation: 0,
                            ),
                          ),
                          // 跳过/下一题
                          ElevatedButton.icon(
                            onPressed: () {
                              if (_currentIndex < _words.length - 1) {
                                setState(() {
                                  _currentIndex++;
                                  _selectedOption = null;
                                  _showResult = false;
                                });
                                _generateOptionsForCurrentWord();
                              } else {
                                _showSessionComplete();
                              }
                            },
                            icon: const Icon(Icons.arrow_forward, size: 18),
                            label: const Text('下一题'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3C8CE7),
                              foregroundColor: Colors.white,
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
}