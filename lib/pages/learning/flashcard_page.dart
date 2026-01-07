import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../providers/word_book_provider.dart';
import '../../services/algorithm_scheduler.dart';
import '../../services/tts_service.dart';
import '../../services/learning_stats_service.dart';

class FlashcardPage extends StatefulWidget {
  final String? bookId;
  final String? bookName;
  final int? unitOffset;
  final int? unitLimit;
  final String? unitName;

  const FlashcardPage({
    super.key,
    this.bookId,
    this.bookName,
    this.unitOffset,
    this.unitLimit,
    this.unitName,
  });

  @override
  State<FlashcardPage> createState() => _FlashcardPageState();
}

class _FlashcardPageState extends State<FlashcardPage> {
  List<Map<String, dynamic>> _words = [];
  int _currentIndex = 0;
  bool _showBack = false;
  bool _isLoading = true;
  bool _isGrading = false;
  final AlgorithmScheduler _scheduler = AlgorithmScheduler.instance;
  final FocusNode _focusNode = FocusNode();

  int _correct = 0;
  int _wrong = 0;
  int _unsure = 0;

  // ignore: unused_element
  Future<void> _toggleCollect() async {
    final word = _currentWord;
    if (word == null) return;

    final provider = WordBookProvider.instance;
    final currentStatus = word['Collected'] ?? 0;
    final newStatus = currentStatus == 0;
    await provider.collectWord(word['WordId'], newStatus);

    if (mounted) {
      setState(() {
        word['Collected'] = newStatus ? 1 : 0;
      });
    }
  }

  // ignore: unused_element
  Future<void> _markAsMastered() async {
    final word = _currentWord;
    if (word == null) return;

    final provider = WordBookProvider.instance;
    await provider.setMastered(word['WordId']);

    _goToNextWord();
  }

  // ignore: unused_element
  Future<void> _postpone() async {
    final word = _currentWord;
    if (word == null) return;

    if (mounted) {
      setState(() {
        _words.removeAt(_currentIndex);
        _words.add(word);
      });
    }
  }

  void _goToNextWord() {
    if (mounted) {
      setState(() {
        if (_currentIndex < _words.length - 1) {
          _currentIndex++;
          _showBack = false;
        } else {
          _showSessionComplete();
        }
      });
    }
  }

  Future<void> _playAudio() async {
    final word = _currentWord;
    if (word != null && word['Word'] != null) {
      await TtsService.instance.speak(word['Word']);
    }
  }

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
    if (_isLoading || _words.isEmpty) return KeyEventResult.ignored;

    // 空格键翻卡
    if (event.logicalKey == LogicalKeyboardKey.space) {
      if (!_showBack) {
        _flipCard();
        return KeyEventResult.handled;
      }
    }

    // 数字键评分（仅在显示答案时有效）
    if (_showBack && !_isGrading) {
      if (event.logicalKey == LogicalKeyboardKey.digit1 ||
          event.logicalKey == LogicalKeyboardKey.numpad1) {
        _grade(1); // 不认识
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.digit2 ||
          event.logicalKey == LogicalKeyboardKey.numpad2) {
        _grade(2); // 模糊
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.digit3 ||
          event.logicalKey == LogicalKeyboardKey.numpad3) {
        _grade(3); // 认识
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.digit4 ||
          event.logicalKey == LogicalKeyboardKey.numpad4) {
        _grade(4); // 太简单
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  Future<void> _loadWords() async {
    final provider = WordBookProvider.instance;
    
    final bookId = widget.bookId;
    if (bookId != null) {
      List<Map<String, dynamic>> loadedWords;
      
      if (widget.unitOffset != null) {
        if (kDebugMode) {
          debugPrint('📚 FlashcardPage loading unit: offset=${widget.unitOffset}, limit=${widget.unitLimit}');
        }
        loadedWords = await provider.getWordsForBookByRange(
          bookId,
          offset: widget.unitOffset!,
          limit: widget.unitLimit ?? 30,
        );
        if (kDebugMode) {
          debugPrint('📚 Loaded ${loadedWords.length} words for unit, first word: ${loadedWords.isNotEmpty ? loadedWords.first['Word'] : 'none'}');
        }
      } else {
        final reviewWords = await provider.getWordsForReview(bookId, limit: 50);
        final newWords = await provider.getWordsForBook(bookId, status: 0, limit: 50);
        loadedWords = [...reviewWords, ...newWords];
      }

      if (mounted) {
        setState(() {
          _words = loadedWords;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Map<String, dynamic>? get _currentWord => 
      _words.isNotEmpty && _currentIndex < _words.length ? _words[_currentIndex] : null;

  void _flipCard() {
    if (mounted) {
      setState(() {
        _showBack = !_showBack;
      });
    }
  }

  Future<void> _grade(int rating) async {
    if (_isGrading) return;

    final word = _currentWord;
    if (word == null) return;

    setState(() => _isGrading = true);

    try {
      final wordId = word['WordId'];
      final provider = WordBookProvider.instance;
      final learnParam = word['LearnParam'] as String?;
      final currentStatus = word['LearnStatus'] ?? 0;

      // 使用调度器计算下次复习
      final result = _scheduler.schedule(learnParam, rating);

      // 更新单词状态
      await provider.updateWordStatus(
        wordId,
        result.newStatus,
        result.learnParam,
        result.nextReview.millisecondsSinceEpoch.toString(),
      );

      // 记录学习统计
      if (currentStatus == 0) {
        await LearningStatsService.instance.recordNewWord();
      } else {
        await LearningStatsService.instance.recordReview();
      }

      if (rating == 1) {
        _wrong++;
      } else if (rating == 2) {
        _unsure++;
      } else {
        _correct++;
      }

      _goToNextWord();
    } finally {
      if (mounted) {
        setState(() => _isGrading = false);
      }
    }
  }

  void _showSessionComplete() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('学习完成！'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green[400]),
            const SizedBox(height: 16),
            Text('本轮学习完成！共学习 ${_words.length} 个单词',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            Text(
              '答对：$_correct | 模糊：$_unsure | 答错：$_wrong',
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
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
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _currentIndex = 0;
                _showBack = false;
                _correct = 0;
                _wrong = 0;
                _unsure = 0;
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
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.unitName ?? widget.bookName ?? '单词学习'),
          actions: [
            if (_currentWord != null)
              IconButton(
                icon: Icon(
                  (_currentWord!['Collected'] ?? 0) == 1
                      ? Icons.star
                      : Icons.star_border,
                ),
                onPressed: _toggleCollect,
              ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _words.isEmpty
                ? _buildEmptyState()
                : _buildContent(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '暂无单词',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            '请先添加单词到词书',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: LinearProgressIndicator(
            value: (_currentIndex + 1) / _words.length,
            backgroundColor: Colors.grey[200],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            '${_currentIndex + 1} / ${_words.length}',
            style: const TextStyle(fontSize: 14, color: Colors.black54),
          ),
        ),
        Expanded(
          child: Center(
            child: _buildFlashCard(),
          ),
        ),
        if (!_showBack)
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  onPressed: _flipCard,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: const Text('显示答案'),
                ),
                const SizedBox(height: 8),
                Text(
                  '按空格键翻卡',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          )
        else
          _buildRatingButtons(),
      ],
    );
  }

  Widget _buildFlashCard() {
    final word = _currentWord;
    if (word == null) return const SizedBox();

    return GestureDetector(
      onTap: _flipCard,
      child: Card(
        elevation: 4,
        margin: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(minHeight: 300),
          padding: const EdgeInsets.all(32),
          child: !_showBack
              ? _buildFrontContent(word)
              : _buildBackContent(word),
        ),
      ),
    );
  }

  Widget _buildFrontContent(Map<String, dynamic> word) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          word['Word'] ?? '',
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        if (word['Symbol'] != null && word['Symbol'].toString().isNotEmpty)
          Text(
            word['Symbol'],
            style: const TextStyle(fontSize: 18, color: Colors.black54),
          ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _playAudio,
          icon: const Icon(Icons.volume_up),
          label: const Text('发音'),
        ),
      ],
    );
  }

  Widget _buildBackContent(Map<String, dynamic> word) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                Text(
                  word['Word'] ?? '',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (word['Symbol'] != null && word['Symbol'].toString().isNotEmpty)
                  Text(
                    word['Symbol'],
                    style: const TextStyle(fontSize: 16, color: Colors.black54),
                  ),
              ],
            ),
          ),
          const Divider(height: 32),
          if (word['Translate'] != null && word['Translate'].toString().isNotEmpty) ...[
            const Text('翻译：', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(word['Translate'], style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
          ],
          if (word['Example'] != null && word['Example'].toString().isNotEmpty) ...[
            const Text('例句：', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(word['Example'], style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic)),
            if (word['ExampleTrans'] != null && word['ExampleTrans'].toString().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                word['ExampleTrans'],
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildRatingButtons() {
    final learnParam = _currentWord?['LearnParam'] as String?;
    final intervals = _scheduler.previewIntervals(learnParam);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 快捷键提示
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '快捷键: 1-不认识  2-模糊  3-认识  4-太简单',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ),
          Row(
            children: [
              Expanded(child: _buildRatingButton(1, '不认识', Colors.red[400]!, intervals[1] ?? '1分钟', Icons.close)),
              const SizedBox(width: 8),
              Expanded(child: _buildRatingButton(2, '模糊', Colors.orange[400]!, intervals[2] ?? '10分钟', Icons.help_outline)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildRatingButton(3, '认识', Colors.green[400]!, intervals[3] ?? '1天', Icons.done)),
              const SizedBox(width: 8),
              Expanded(child: _buildRatingButton(4, '太简单', Colors.blue[400]!, intervals[4] ?? '4天', Icons.done_all)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRatingButton(int rating, String label, Color color, String interval, IconData icon) {
    return ElevatedButton(
      onPressed: _isGrading ? null : () => _grade(rating),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          Text(interval, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}