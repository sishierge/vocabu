import 'package:flutter/material.dart';
import '../../providers/word_book_provider.dart';
import '../../services/algorithm_scheduler.dart';
import '../../services/tts_service.dart';
import '../../services/learning_stats_service.dart';

class ListLearningPage extends StatefulWidget {
  final String? bookId;
  final String? bookName;

  const ListLearningPage({super.key, this.bookId, this.bookName});

  @override
  State<ListLearningPage> createState() => _ListLearningPageState();
}

class _ListLearningPageState extends State<ListLearningPage> {
  List<Map<String, dynamic>> _words = [];
  int _currentIndex = 0;
  bool _maskTranslation = true;
  bool _maskWord = false;
  bool _isLoading = true;
  final AlgorithmScheduler _scheduler = AlgorithmScheduler.instance;
  final ScrollController _scrollController = ScrollController();

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
      final reviewWords = await provider.getWordsForReview(bookId, limit: 50);
      final newWords = await provider.getWordsForBook(bookId, status: 0, limit: 50);

      setState(() {
        _words = [...reviewWords, ...newWords];
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic>? get _currentWord =>
      _words.isNotEmpty && _currentIndex < _words.length ? _words[_currentIndex] : null;

  Future<void> _grade(int rating) async {
    if (!mounted || _currentWord == null) return;

    final word = _currentWord!;
    final wordId = word['WordId'] as String;
    final learnParam = word['LearnParam'] as String?;
    final result = _scheduler.schedule(learnParam, rating);

    int newStatus = rating >= 3 && result.reps >= 3 ? 2 : 1;

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

    // 更新本地数据
    _words[_currentIndex]['LearnStatus'] = newStatus;
    _words[_currentIndex]['LearnParam'] = result.learnParam;

    if (!mounted) return;

    setState(() {
      if (_currentIndex < _words.length - 1) {
        _currentIndex++;
        _scrollToCurrentWord();
      } else {
        _showSessionComplete();
      }
    });
  }

  void _scrollToCurrentWord() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _currentIndex * 72.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _showSessionComplete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('学习完成！'),
        content: Text('本次学习了 ${_words.length} 个单词'),
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
              _loadWords();
              setState(() => _currentIndex = 0);
            },
            child: const Text('继续学习'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            const Text('列表背单词', style: TextStyle(color: Colors.black, fontSize: 16)),
            const Spacer(),
            if (!_isLoading && _words.isNotEmpty)
              Text('${_currentIndex + 1}/${_words.length}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 14)),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF3C8CE7)),
            onPressed: () {
              _loadWords();
              setState(() => _currentIndex = 0);
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _words.isEmpty
              ? const Center(child: Text('暂无单词'))
              : Column(
                  children: [
                    // Toggle buttons
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          _ToggleChip('遮挡译文', _maskTranslation, () {
                            setState(() => _maskTranslation = !_maskTranslation);
                          }),
                          const SizedBox(width: 8),
                          _ToggleChip('遮挡单词', _maskWord, () {
                            setState(() => _maskWord = !_maskWord);
                          }),
                        ],
                      ),
                    ),
                    // Current word card
                    if (_currentWord != null)
                      Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  _currentWord!['Word'] as String? ?? '',
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: Icon(Icons.volume_up_outlined, color: Colors.grey[600], size: 20),
                                  onPressed: () {
                                    final word = _currentWord!['Word'] as String? ?? '';
                                    TtsService.instance.speak(word);
                                  },
                                ),
                                IconButton(
                                  icon: Icon(
                                    (_currentWord!['Collected'] as int? ?? 0) == 1
                                        ? Icons.star : Icons.star_border,
                                    color: (_currentWord!['Collected'] as int? ?? 0) == 1
                                        ? Colors.amber : Colors.grey[600],
                                    size: 20
                                  ),
                                  onPressed: () async {
                                    final wordId = _currentWord!['WordId'] as String;
                                    final isCollected = (_currentWord!['Collected'] as int? ?? 0) == 1;
                                    await WordBookProvider.instance.collectWord(wordId, !isCollected);
                                    setState(() {
                                      _words[_currentIndex]['Collected'] = isCollected ? 0 : 1;
                                    });
                                  },
                                ),
                              ],
                            ),
                            Text(_currentWord!['Symbol'] as String? ?? '', style: TextStyle(color: Colors.grey[600])),
                            const SizedBox(height: 4),
                            Text(_currentWord!['Translate'] as String? ?? '', style: TextStyle(color: Colors.grey[700])),
                            const SizedBox(height: 12),
                            // Grading buttons - dynamic intervals
                            Builder(
                              builder: (context) {
                                final learnParam = _currentWord!['LearnParam'] as String?;
                                final intervals = _scheduler.previewIntervals(learnParam);

                                return Row(
                                  children: [
                                    _GradeButton('不认识', intervals[1] ?? '1分钟', Colors.red, () => _grade(1)),
                                    const SizedBox(width: 16),
                                    _GradeButton('模糊', intervals[2] ?? '10分钟', Colors.orange, () => _grade(2)),
                                    const SizedBox(width: 16),
                                    _GradeButton('认识', intervals[3] ?? '1天', Colors.green, () => _grade(3)),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    // Word list
                    Expanded(
                      child: ListView.separated(
                        controller: _scrollController,
                        itemCount: _words.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[200]),
                        itemBuilder: (context, index) {
                          final word = _words[index];
                          final isCurrent = index == _currentIndex;
                          return GestureDetector(
                            onTap: () => setState(() => _currentIndex = index),
                            child: Container(
                              color: isCurrent ? Colors.green[50] : Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _maskWord && !isCurrent
                                              ? '--------'
                                              : word['Word'] as String? ?? '',
                                          style: TextStyle(
                                            fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                                          ),
                                        ),
                                        Text(
                                          word['Symbol'] as String? ?? '',
                                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!_maskTranslation || isCurrent)
                                    Expanded(
                                      child: Text(
                                        word['Translate'] as String? ?? '',
                                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleChip(this.label, this.isSelected, this.onTap);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.grey[200] : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
      ),
    );
  }
}

class _GradeButton extends StatelessWidget {
  final String label;
  final String interval;
  final Color color;
  final VoidCallback onTap;

  const _GradeButton(this.label, this.interval, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text('$label - $interval', style: TextStyle(fontSize: 12, color: color)),
      ),
    );
  }
}
