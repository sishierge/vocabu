import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../providers/word_book_provider.dart';
import '../../services/algorithm_scheduler.dart';
import '../../services/tts_service.dart';
import '../../services/learning_stats_service.dart';

/// 拼写练习 - 参考高级拼写的设计
class SpellingPage extends StatefulWidget {
  final String? bookId;
  final String? bookName;

  const SpellingPage({super.key, this.bookId, this.bookName});

  @override
  State<SpellingPage> createState() => _SpellingPageState();
}

class _SpellingPageState extends State<SpellingPage> {
  List<Map<String, dynamic>> _words = [];
  int _currentIndex = 0;
  int _correctCount = 0;
  bool _isLoading = true;
  
  // 核心状态 - 参考高级拼写的设计
  String _targetWord = '';  // 当前目标单词（小写，用于比较）
  String _originalWord = ''; // 原始单词（保留大小写，用于显示）
  String _userInput = '';   // 用户输入
  bool _showFullAnswer = false;  // 是否显示完整答案
  
  // 设置项
  bool _showFirstLetter = true;
  bool _autoPlay = true;
  
  final FocusNode _focusNode = FocusNode();
  final AlgorithmScheduler _scheduler = AlgorithmScheduler.instance;

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  Future<void> _loadWords() async {
    setState(() => _isLoading = true);
    
    final provider = WordBookProvider.instance;
    final bookId = widget.bookId ?? provider.books.firstOrNull?.bookId;
    
    if (bookId != null) {
      final reviewWords = await provider.getWordsForReview(bookId, limit: 30);
      final newWords = await provider.getWordsForBook(bookId, status: 0, limit: 20);
      
      if (!mounted) return;
      
      setState(() {
        _words = [...reviewWords, ...newWords];
        _words.shuffle();
        _isLoading = false;
      });
      
      if (_words.isNotEmpty) {
        _initCurrentWord();
      }
    } else {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
    
    _focusNode.requestFocus();
  }

  void _initCurrentWord() {
    if (_currentIndex >= _words.length) return;
    
    final word = _words[_currentIndex];
    _originalWord = (word['Word'] as String? ?? '').trim(); // 保留原始大小写
    _targetWord = _originalWord.toLowerCase(); // 小写用于比较
    _userInput = '';
    _showFullAnswer = false;
    setState(() {});
    
    // 自动播放发音
    if (_autoPlay && _targetWord.isNotEmpty) {
      TtsService.instance.speak(_originalWord);
    }
  }

  Map<String, dynamic>? get _currentWord => 
      _words.isNotEmpty && _currentIndex < _words.length ? _words[_currentIndex] : null;

  String get _translation => _currentWord?['Translate'] as String? ?? '';
  String get _symbol => _currentWord?['Symbol'] as String? ?? 
                        _currentWord?['SymbolUs'] as String? ?? '';

  /// 键盘事件处理 - 直接参考高级拼写
  void _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    
    // 已显示答案时，按回车/空格进入下一题
    if (_showFullAnswer) {
      if (event.logicalKey == LogicalKeyboardKey.enter || 
          event.logicalKey == LogicalKeyboardKey.space) {
        _nextWord();
      }
      return;
    }
    
    // Tab键 - 提示下一个字母
    if (event.logicalKey == LogicalKeyboardKey.tab) {
      if (_userInput.length < _targetWord.length) {
        setState(() {
          _userInput += _targetWord[_userInput.length];
        });
      }
      return;
    }
    
    // Space键 - 放弃，显示答案
    if (event.logicalKey == LogicalKeyboardKey.space) {
      setState(() => _showFullAnswer = true);
      return;
    }
    
    // Backspace - 删除
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      if (_userInput.isNotEmpty) {
        setState(() => _userInput = _userInput.substring(0, _userInput.length - 1));
      }
      return;
    }
    
    // Enter - 手动提交
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (_userInput.isNotEmpty) {
        _checkAndShowResult();
      }
      return;
    }
    
    // 字母输入
    if (event.character != null && RegExp(r"[a-zA-Z\-']").hasMatch(event.character!)) {
      setState(() => _userInput += event.character!);
      
      // 拼写完成检查 - 直接在这里判断，不调用异步方法
      if (_userInput.length == _targetWord.length) {
        _checkAndShowResult();
      }
    }
  }

  /// 检查答案并显示结果 - 同步方法，不调用异步操作
  void _checkAndShowResult() {
    final isCorrect = _userInput.toLowerCase() == _targetWord.toLowerCase();
    
    if (isCorrect) {
      _correctCount++;
    }
    
    setState(() => _showFullAnswer = true);
    
    // 异步更新数据库（不阻塞UI）
    _updateWordStatus(isCorrect);
  }

  /// 异步更新数据库
  Future<void> _updateWordStatus(bool isCorrect) async {
    final word = _currentWord;
    if (word == null) return;

    final wordId = word['WordId'] as String;
    final learnParam = word['LearnParam'] as String?;

    final rating = isCorrect ? 3 : 1;
    final result = _scheduler.schedule(learnParam, rating);

    int newStatus = isCorrect && result.reps >= 3 ? 2 : 1;

    await WordBookProvider.instance.updateWordStatus(
      wordId,
      newStatus,
      result.learnParam,
      result.nextReview.millisecondsSinceEpoch.toString(),
    );

    // 记录学习统计
    final currentStatus = word['LearnStatus'] as int? ?? 0;
    if (currentStatus == 0) {
      LearningStatsService.instance.recordNewWord();
    } else {
      LearningStatsService.instance.recordReview();
    }
  }

  void _nextWord() {
    if (_currentIndex < _words.length - 1) {
      _currentIndex++;
      _initCurrentWord();
    } else {
      _showSessionComplete();
    }
    _focusNode.requestFocus();
  }

  void _showSessionComplete() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('拼写完成！'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.spellcheck, size: 64, color: Colors.blue[400]),
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
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(
            children: [
              const Text('拼写练习', style: TextStyle(color: Colors.black, fontSize: 16)),
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
                        Icon(Icons.spellcheck, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        const Text('暂无需要拼写的单词'),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      // 进度条
                      LinearProgressIndicator(
                        value: (_currentIndex + 1) / _words.length,
                        backgroundColor: Colors.grey[200],
                        valueColor: const AlwaysStoppedAnimation(Color(0xFF3C8CE7)),
                      ),
                      const SizedBox(height: 24),
                      
                      // 提示模式切换
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FilterChip(
                              label: const Text('显示首字母'),
                              selected: _showFirstLetter,
                              onSelected: (v) => setState(() => _showFirstLetter = v),
                              selectedColor: Colors.blue[100],
                            ),
                            const SizedBox(width: 8),
                            FilterChip(
                              label: const Text('自动播放'),
                              selected: _autoPlay,
                              onSelected: (v) => setState(() => _autoPlay = v),
                              selectedColor: Colors.blue[100],
                            ),
                          ],
                        ),
                      ),
                      
                      const Spacer(),
                      
                      // 翻译和音标提示区
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.blue[100]!),
                        ),
                        child: Column(
                          children: [
                            Text(
                              _translation,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                              textAlign: TextAlign.center,
                            ),
                            if (_symbol.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                _symbol,
                                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                              ),
                            ],
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () => TtsService.instance.speak(_targetWord),
                              icon: const Icon(Icons.volume_up_rounded, size: 20),
                              label: const Text('播放发音'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3C8CE7),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // 输入显示区 - 参考高级拼写的 _buildInputDisplay
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: _buildInputDisplay(),
                      ),
                      
                      const Spacer(),
                      
                      // 底部按钮/提示
                      if (_showFullAnswer)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: ElevatedButton(
                            onPressed: _nextWord,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3C8CE7),
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('继续 (Enter)', style: TextStyle(color: Colors.white)),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Text(
                                '输入单词拼写...',
                                style: TextStyle(color: Colors.grey[500], fontSize: 14),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tab = 提示下一个字母  |  Space = 查看答案',
                                style: TextStyle(color: Colors.grey[400], fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }

  /// 输入显示 - 直接参考高级拼写的 _buildInputDisplay
  Widget _buildInputDisplay() {
    // 显示完整答案模式
    if (_showFullAnswer) {
      final isCorrect = _userInput.toLowerCase() == _targetWord.toLowerCase();
      return Column(
        children: [
          // 正确答案 - 使用原始大小写
          Text(
            _originalWord,
            style: TextStyle(
              fontSize: 32, 
              fontWeight: FontWeight.bold, 
              color: isCorrect ? Colors.green : const Color(0xFF3C8CE7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          // 结果提示
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: isCorrect ? Colors.green[50] : Colors.red[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isCorrect ? Icons.check_circle : Icons.cancel,
                  color: isCorrect ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  isCorrect ? '正确！' : '再试试',
                  style: TextStyle(
                    color: isCorrect ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    
    // 输入模式 - 完全按照高级拼写的方式
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 4,
      runSpacing: 8,
      children: List.generate(_targetWord.length, (i) {
        final isTyped = i < _userInput.length;
        // 首字母提示：当启用且是第一个字符且用户未输入时显示
        final showHint = _showFirstLetter && i == 0 && !isTyped;
        final char = isTyped ? _userInput[i] : (showHint ? _originalWord[0] : '');
        final isCorrect = isTyped && _userInput[i].toLowerCase() == _targetWord[i].toLowerCase();
        
        // 实时颜色反馈：正确蓝色，错误红色，提示灰色
        Color textColor = Colors.grey[400]!;
        if (isTyped) {
          textColor = isCorrect ? const Color(0xFF3C8CE7) : Colors.red;
        } else if (showHint) {
          textColor = Colors.grey[500]!;
        }
        
        return Container(
          width: 36,
          height: 48,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: isTyped ? textColor : Colors.grey[300]!, width: 3)),
          ),
          child: Center(
            child: Text(
              char,  // 直接显示，不转换大小写
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
            ),
          ),
        );
      }),
    );
  }
}