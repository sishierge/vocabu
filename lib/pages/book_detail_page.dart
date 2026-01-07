import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vocabu/widgets/book_detail_widgets.dart';
import 'package:vocabu/providers/word_book_provider.dart';
import 'learning/flashcard_page.dart';
import 'learning/quiz_page.dart';
import 'learning/spelling_page.dart';
import 'learning/list_page.dart';
import 'learning/advanced_spelling_page.dart';
import '../services/tts_service.dart';

class BookDetailPage extends StatefulWidget {
  final String bookName;
  const BookDetailPage({super.key, required this.bookName});

  @override
  State<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends State<BookDetailPage> {
  int _selectedTab = 2; // Default to 学习 tab
  int _vocabFilter = 0; // 词汇筛选: 0=全部, 1=未学习, 2=学习中, 3=已掌握, 4=收藏

  final List<String> _tabs = ['单元', '词汇', '学习', '数据'];
  final List<String> _filterLabels = ['全部', '未学习', '学习中', '已掌握', '收藏夹'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
          children: [
            Icon(Icons.home_outlined, size: 18, color: Colors.grey),
            SizedBox(width: 8),
            Text('我的主页', style: TextStyle(color: Colors.grey, fontSize: 14)),
          ],
        ),
        actions: _tabs.asMap().entries.map((entry) {
          final isSelected = _selectedTab == entry.key;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TextButton(
              onPressed: () => setState(() => _selectedTab = entry.key),
              style: TextButton.styleFrom(
                backgroundColor: isSelected ? Colors.grey[100] : Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              child: Text(
                entry.value,
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.grey[600],
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
      body: Column(
        children: [
          // Book title bar (只显示书名，返回按钮在 AppBar 中)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                Text(widget.bookName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          // Tab content
          Expanded(child: _buildTabContent()),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildUnitView();
      case 1:
        return _buildVocabView();
      case 2:
        return _buildStudyView();
      case 3:
        return _buildDataView();
      default:
        return const SizedBox();
    }
  }


  Widget _buildUnitView() {
    final books = WordBookProvider.instance.books;
    if (books.isEmpty) {
      return const Center(child: Text('暂无词书'));
    }

    final book = books.firstWhere(
      (b) => b.bookName == widget.bookName,
      orElse: () => books.first,
    );
    final bookId = book.bookId;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getUnitsOrGenerateFromWords(bookId, book.wordCount),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.isEmpty) return const Center(child: Text('暂无单词，无法生成单元'));

        final colorScheme = Theme.of(context).colorScheme;

        return GridView.builder(
          padding: const EdgeInsets.all(24),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.5,
          ),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final unit = snapshot.data![index];
            // 兼容数据库字段名（大写）和虚拟单元字段名（小写）
            final wordCount = unit['wordCount'] ?? unit['WordCount'] ?? 0;
            final mastered = unit['mastered'] ?? 0;
            final progress = wordCount > 0 ? mastered / wordCount : 0.0;
            return InkWell(
              onTap: () => _openUnitLearning(bookId, unit),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Unit ${index + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.play_circle_outline, size: 20, color: colorScheme.primary),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      unit['unitName'] ?? unit['UnitName'] ?? '单元 ${index + 1}',
                      style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text('$wordCount 词', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// 获取单元或根据单词自动生成单元
  /// 使用基于学习科学的算法来划分单元:
  /// 1. 艾宾浩斯遗忘曲线 - 考虑复习间隔
  /// 2. 认知负荷理论 - 每个学习会话15-25个单词最佳
  /// 3. 单词难度 - 基于单词长度和词频分级
  /// 4. 学习状态 - 新词/复习词混合编排
  Future<List<Map<String, dynamic>>> _getUnitsOrGenerateFromWords(String bookId, int totalWordCount) async {
    if (kDebugMode) {
      debugPrint('📚 _getUnitsOrGenerateFromWords: bookId=$bookId, totalWordCount=$totalWordCount');
    }

    // 先尝试从数据库获取单元
    final existingUnits = await WordBookProvider.instance.getUnitsForBook(bookId);
    if (existingUnits.isNotEmpty) {
      if (kDebugMode) {
        debugPrint('📚 Found ${existingUnits.length} existing units from database');
      }
      return existingUnits;
    }

    // 如果没有单元，使用学习算法自动生成虚拟单元
    if (totalWordCount <= 0) {
      if (kDebugMode) {
        debugPrint('⚠️ totalWordCount is 0 or negative, returning empty list');
      }
      return [];
    }

    // 获取所有单词用于分析
    List<Map<String, dynamic>> allWords = [];
    try {
      allWords = await WordBookProvider.instance.getWordsForBook(bookId, limit: totalWordCount);
      if (kDebugMode) {
        debugPrint('📚 Fetched ${allWords.length} words for analysis (expected: $totalWordCount)');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to get words for analysis: $e');
      }
    }

    if (allWords.isEmpty) {
      // 如果无法获取单词数据，降级为基础算法
      if (kDebugMode) {
        debugPrint('⚠️ allWords is empty, using basic algorithm with totalWordCount=$totalWordCount');
      }
      return _generateBasicUnits(bookId, totalWordCount);
    }

    // 使用学习算法划分单元
    return _generateSmartUnits(bookId, allWords, totalWordCount);
  }

  /// 基于学习科学的智能单元划分算法
  Future<List<Map<String, dynamic>>> _generateSmartUnits(String bookId, List<Map<String, dynamic>> allWords, int totalWordCount) async {
    // === 学习算法核心参数 ===
    // 基于认知负荷理论：工作记忆容量约7±2项
    // 结合词汇学习研究：每个学习会话15-25个新词最有效
    const int minWordsPerUnit = 15;  // 最少单词数（保证学习效率）
    const int maxWordsPerUnit = 25;  // 最多单词数（避免认知超载）
    const int idealWordsPerUnit = 20; // 理想单词数

    // 如果单词列表为空但总数不为0，直接使用基础算法
    if (allWords.isEmpty && totalWordCount > 0) {
      if (kDebugMode) {
        debugPrint('⚠️ allWords is empty but totalWordCount=$totalWordCount, using basic algorithm');
      }
      return await _generateBasicUnits(bookId, totalWordCount);
    }

    List<Map<String, dynamic>> virtualUnits = [];

    // 第一步：按难度分级（基于单词长度和复杂度）
    // 研究表明：短单词（1-4字母）较易，中等（5-7字母），长单词（8+字母）较难
    List<Map<String, dynamic>> easyWords = [];
    List<Map<String, dynamic>> mediumWords = [];
    List<Map<String, dynamic>> hardWords = [];

    for (var word in allWords) {
      final wordText = word['Word'] as String? ?? '';
      final difficulty = _calculateWordDifficulty(wordText);

      if (difficulty <= 1) {
        easyWords.add(word);
      } else if (difficulty <= 2) {
        mediumWords.add(word);
      } else {
        hardWords.add(word);
      }
    }

    // 第二步：根据难度比例动态计算每单元的单词数
    // 艾宾浩斯曲线启示：难词需要更多重复，所以难词单元应该更小
    // 难词单元：15-18词，中等：18-22词，简单：20-25词
    int easyUnitSize = maxWordsPerUnit;
    int mediumUnitSize = idealWordsPerUnit;
    int hardUnitSize = minWordsPerUnit;

    // 第三步：按学习顺序生成单元
    // 学习策略：交替安排难易单元，避免疲劳
    // 遵循"先易后难"原则，同时混合编排促进记忆巩固

    int unitIndex = 0;
    int globalWordIndex = 0;

    // 创建难度混合的单元列表
    List<List<Map<String, dynamic>>> wordGroups = [];

    // 先处理简单单词（优先学习高频基础词）
    for (int i = 0; i < easyWords.length; i += easyUnitSize) {
      final end = (i + easyUnitSize > easyWords.length) ? easyWords.length : i + easyUnitSize;
      wordGroups.add(easyWords.sublist(i, end));
    }

    // 然后处理中等难度单词
    for (int i = 0; i < mediumWords.length; i += mediumUnitSize) {
      final end = (i + mediumUnitSize > mediumWords.length) ? mediumWords.length : i + mediumUnitSize;
      wordGroups.add(mediumWords.sublist(i, end));
    }

    // 最后处理困难单词（需要更多注意力）
    for (int i = 0; i < hardWords.length; i += hardUnitSize) {
      final end = (i + hardUnitSize > hardWords.length) ? hardWords.length : i + hardUnitSize;
      wordGroups.add(hardWords.sublist(i, end));
    }

    // 第四步：生成单元数据
    for (var group in wordGroups) {
      if (group.isEmpty) continue;

      // 计算该组的难度标签
      final avgDifficulty = group.fold<double>(0, (sum, w) {
        return sum + _calculateWordDifficulty(w['Word'] as String? ?? '');
      }) / group.length;

      String difficultyLabel;
      if (avgDifficulty <= 1.3) {
        difficultyLabel = '基础';
      } else if (avgDifficulty <= 2.3) {
        difficultyLabel = '进阶';
      } else {
        difficultyLabel = '挑战';
      }

      // 统计已掌握单词数
      final masteredCount = group.where((w) => (w['LearnStatus'] as int? ?? 0) == 2).length;

      virtualUnits.add({
        'unitId': 'smart_$unitIndex',
        'unitName': '$difficultyLabel ${unitIndex + 1}',
        'wordCount': group.length,
        'startIndex': globalWordIndex,
        'mastered': masteredCount,
        'difficulty': avgDifficulty,
        'difficultyLabel': difficultyLabel,
      });

      globalWordIndex += group.length;
      unitIndex++;
    }

    // 如果生成的单元为空，降级为基础算法
    if (virtualUnits.isEmpty) {
      return await _generateBasicUnits(bookId, totalWordCount);
    }

    return virtualUnits;
  }

  /// 计算单词难度分数 (1-3分)
  /// 基于：单词长度、音节数量估算、常见词缀
  double _calculateWordDifficulty(String word) {
    if (word.isEmpty) return 1.0;

    final length = word.length;
    double difficulty = 1.0;

    // 基于长度的难度 (研究表明长单词更难记忆)
    if (length <= 4) {
      difficulty = 1.0; // 短词容易
    } else if (length <= 6) {
      difficulty = 1.5;
    } else if (length <= 8) {
      difficulty = 2.0;
    } else if (length <= 10) {
      difficulty = 2.5;
    } else {
      difficulty = 3.0; // 超长词最难
    }

    // 考虑常见词缀（有规律的词相对容易）
    final commonPrefixes = ['un', 're', 'in', 'dis', 'pre', 'mis', 'over', 'out'];
    final commonSuffixes = ['ing', 'ed', 'ly', 'tion', 'ness', 'ment', 'able', 'ful', 'less'];

    bool hasCommonAffix = false;
    for (final prefix in commonPrefixes) {
      if (word.toLowerCase().startsWith(prefix)) {
        hasCommonAffix = true;
        break;
      }
    }
    for (final suffix in commonSuffixes) {
      if (word.toLowerCase().endsWith(suffix)) {
        hasCommonAffix = true;
        break;
      }
    }

    // 有常见词缀的词相对容易理解
    if (hasCommonAffix && difficulty > 1.0) {
      difficulty -= 0.3;
    }

    // 检查是否包含不常见字母组合（增加难度）
    final uncommonPatterns = RegExp(r'(ph|gh|ough|augh|eigh|sch|chr|ps)');
    if (uncommonPatterns.hasMatch(word.toLowerCase())) {
      difficulty += 0.3;
    }

    return difficulty.clamp(1.0, 3.0);
  }

  /// 基础单元生成算法（降级方案）
  Future<List<Map<String, dynamic>>> _generateBasicUnits(String bookId, int totalWordCount) async {
    if (kDebugMode) {
      debugPrint('📚 _generateBasicUnits: bookId=$bookId, totalWordCount=$totalWordCount');
    }

    // 使用认知负荷理论的建议值：20词/单元
    const wordsPerUnit = 20;
    final unitCount = (totalWordCount / wordsPerUnit).ceil();

    if (kDebugMode) {
      debugPrint('📚 Will generate $unitCount units with ~$wordsPerUnit words each');
    }

    List<Map<String, dynamic>> virtualUnits = [];
    for (int i = 0; i < unitCount; i++) {
      final startIndex = i * wordsPerUnit;
      final wordsInUnit = (i == unitCount - 1)
          ? totalWordCount - startIndex
          : wordsPerUnit;

      // 确保 wordsInUnit 至少为1（边界情况处理）
      final finalWordsInUnit = wordsInUnit > 0 ? wordsInUnit : wordsPerUnit;

      // 查询该单元范围内的已掌握单词数
      int masteredCount = 0;
      try {
        final words = await WordBookProvider.instance.getWordsForBookByRange(
          bookId,
          offset: startIndex,
          limit: finalWordsInUnit,
        );
        masteredCount = words.where((w) => (w['LearnStatus'] as int? ?? 0) == 2).length;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Failed to get mastered count: $e');
        }
      }

      virtualUnits.add({
        'unitId': 'basic_$i',
        'unitName': '第 ${i + 1} 单元',
        'wordCount': finalWordsInUnit,
        'startIndex': startIndex,
        'mastered': masteredCount,
      });

      if (kDebugMode) {
        debugPrint('📚 Unit ${i + 1}: startIndex=$startIndex, wordCount=$finalWordsInUnit');
      }
    }

    return virtualUnits;
  }

  /// 打开单元学习页面
  void _openUnitLearning(String bookId, Map<String, dynamic> unit) {
    final startIndex = unit['startIndex'] as int? ?? 0;
    // 兼容数据库字段名（大写）和虚拟单元字段名（小写）
    final wordCount = unit['wordCount'] ?? unit['WordCount'] ?? 30;
    final unitName = unit['unitName'] ?? unit['UnitName'] ?? '单元';

    if (kDebugMode) {
      debugPrint('📚 Opening unit: $unitName, startIndex: $startIndex, wordCount: $wordCount');
    }

    // 导航到单元学习页面
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FlashcardPage(
          bookId: bookId,
          bookName: widget.bookName,
          unitOffset: startIndex,
          unitLimit: wordCount,
          unitName: unitName,
        ),
      ),
    );
  }

  Widget _buildVocabView() {
    final books = WordBookProvider.instance.books;
    if (books.isEmpty) {
      return const Center(child: Text('暂无词书'));
    }

    final book = books.firstWhere(
      (b) => b.bookName == widget.bookName,
      orElse: () => books.first,
    );

    return _LazyWordGrid(
      key: ValueKey('vocab_${book.bookId}_$_vocabFilter'),
      bookId: book.bookId,
      filter: _vocabFilter,
      filterLabels: _filterLabels,
      onFilterChanged: (filter) => setState(() => _vocabFilter = filter),
    );
  }

  Widget _buildStudyView() {
    final books = WordBookProvider.instance.books;
    if (books.isEmpty) {
      return const Center(child: Text('暂无词书'));
    }

    final book = books.firstWhere((b) => b.bookName == widget.bookName, orElse: () => books.first);
    final bookId = book.bookId;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Select words section
          Row(
            children: [
              Container(width: 3, height: 16, color: Colors.black),
              const SizedBox(width: 8),
              const Text('选择单词', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              StudyCard('学习新词', '${book.newCount}', '/${book.newCount}', Colors.green, Icons.school, true),
              const SizedBox(width: 16),
              StudyCard('复习单词', '${book.reviewCount}', '/${book.reviewCount}', Colors.orange, Icons.refresh, false),
              const SizedBox(width: 16),
              StudyCard('我的收藏', '${book.collectedCount}', '', Colors.amber, Icons.star, false),
              const SizedBox(width: 16),
              StudyCard('未掌握', '${book.wordCount - book.masteredCount}', '', Colors.blue, Icons.grid_view, false),
            ],
          ),
          const SizedBox(height: 32),
          // Learning tools section
          Row(
            children: [
              Container(width: 3, height: 16, color: Colors.black),
              const SizedBox(width: 8),
              const Text('学习工具选择', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ToolCard('卡片背单词', '正反面双面卡背单词', Colors.blue, Icons.style, () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => FlashcardPage(bookId: bookId, bookName: book.bookName)));
              }),
              const SizedBox(width: 16),
              ToolCard('列表背单词', '快速背单词', Colors.green, Icons.list_alt, () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => ListLearningPage(bookId: bookId, bookName: book.bookName)));
              }),
              const SizedBox(width: 16),
              ToolCard('选项练习', '根据单词选择正确选项', Colors.pink, Icons.quiz, () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => QuizPage(bookId: bookId, bookName: book.bookName)));
              }),
              const SizedBox(width: 16),
              ToolCard('拼写练习', '拼写/默写', Colors.amber, Icons.keyboard, () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => SpellingPage(bookId: bookId, bookName: book.bookName)));
              }),
              const SizedBox(width: 16),
              ToolCard('高级拼写', '例句拼写', Colors.teal, Icons.text_fields, () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => AdvancedSpellingPage(bookId: bookId, bookName: book.bookName)));
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDataView() {
    final books = WordBookProvider.instance.books;
    if (books.isEmpty) {
      return const Center(child: Text('暂无词书'));
    }

    final book = books.firstWhere((b) => b.bookName == widget.bookName, orElse: () => books.first);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats row
          Row(
            children: [
              DataCard('新词', '${book.newCount}', Colors.green, Icons.fiber_new),
              DataCard('学习中', '${book.learningCount}', Colors.orange, Icons.hourglass_empty),
              DataCard('已掌握', '${book.masteredCount}', Colors.purple, Icons.check_circle),
              DataCard('单词总数', '${book.wordCount}', Colors.indigo, Icons.grid_view),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Icon(Icons.trending_up, color: Colors.blue[200]),
                    const Text('掌握进度'),
                    Text('${(book.progress * 100).toStringAsFixed(2)}%', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Text('近期新学统计', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Container(
            height: 150,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(child: Text('柱状图', style: TextStyle(color: Colors.grey))),
          ),
          const SizedBox(height: 32),
          const Text('复习日历', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: List.generate(10, (i) {
                final isToday = i == 2;
                return Expanded(
                  child: Column(
                    children: [
                      Text('${28 + i}', style: TextStyle(color: isToday ? Colors.blue : Colors.black)),
                      Text(isToday ? '102' : '0', style: TextStyle(color: isToday ? Colors.orange : Colors.grey, fontSize: 12)),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

/// 懒加载单词网格组件
class _LazyWordGrid extends StatefulWidget {
  final String bookId;
  final int filter;
  final List<String> filterLabels;
  final void Function(int) onFilterChanged;

  const _LazyWordGrid({
    super.key,
    required this.bookId,
    required this.filter,
    required this.filterLabels,
    required this.onFilterChanged,
  });

  @override
  State<_LazyWordGrid> createState() => _LazyWordGridState();
}

class _LazyWordGridState extends State<_LazyWordGrid> {
  static const int _pageSize = 50; // 每次加载50个单词

  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _words = [];
  int _totalCount = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 滚动监听 - 触发加载更多
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  /// 获取筛选参数
  (int?, bool?) _getFilterParams() {
    switch (widget.filter) {
      case 1: return (0, null); // 未学习
      case 2: return (1, null); // 学习中
      case 3: return (2, null); // 已掌握
      case 4: return (null, true); // 收藏
      default: return (null, null); // 全部
    }
  }

  /// 初始加载
  Future<void> _loadInitial() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _words.clear();
      _hasMore = true;
    });

    try {
      final (status, collected) = _getFilterParams();

      // 获取总数
      _totalCount = await WordBookProvider.instance.getWordCountForBook(
        bookId: widget.bookId,
        status: status,
        collected: collected,
      );

      // 获取第一页数据
      final data = await WordBookProvider.instance.getWordsForBookPaginated(
        bookId: widget.bookId,
        status: status,
        collected: collected,
        offset: 0,
        limit: _pageSize,
      );

      if (mounted) {
        setState(() {
          _words.addAll(data);
          _hasMore = data.length == _pageSize && _words.length < _totalCount;
          _isLoading = false;
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading words: $e');
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isInitialized = true;
        });
      }
    }
  }

  /// 加载更多
  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;

    setState(() => _isLoading = true);

    try {
      final (status, collected) = _getFilterParams();

      final data = await WordBookProvider.instance.getWordsForBookPaginated(
        bookId: widget.bookId,
        status: status,
        collected: collected,
        offset: _words.length,
        limit: _pageSize,
      );

      if (mounted) {
        setState(() {
          _words.addAll(data);
          _hasMore = data.length == _pageSize && _words.length < _totalCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading more words: $e');
      }
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // 筛选标签
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            children: widget.filterLabels.asMap().entries.map((entry) {
              final isSelected = widget.filter == entry.key;
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: InkWell(
                  onTap: () => widget.onFilterChanged(entry.key),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF3C8CE7) : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      entry.value,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[600],
                        fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // 数量提示
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
          child: Row(
            children: [
              Text(
                '共 $_totalCount 词${_words.length < _totalCount ? '（已加载 ${_words.length}）' : ''}',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        ),

        // 单词网格
        Expanded(
          child: _words.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 8),
                      Text(
                        '暂无${widget.filterLabels[widget.filter]}单词',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.2,
                  ),
                  itemCount: _words.length + (_hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    // 加载更多指示器
                    if (index >= _words.length) {
                      return Container(
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      );
                    }

                    return _WordCard(
                      word: _words[index],
                      onCollectChanged: () => setState(() {}),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// 单词卡片组件
class _WordCard extends StatelessWidget {
  final Map<String, dynamic> word;
  final VoidCallback onCollectChanged;

  const _WordCard({
    required this.word,
    required this.onCollectChanged,
  });

  @override
  Widget build(BuildContext context) {
    final status = word['LearnStatus'] as int? ?? 0;
    final isCollected = (word['Collected'] as int? ?? 0) == 1;

    // 根据状态设置边框颜色
    Color borderColor;
    switch (status) {
      case 0:
        borderColor = Colors.grey;
        break;
      case 1:
        borderColor = Colors.orange;
        break;
      case 2:
        borderColor = Colors.green;
        break;
      default:
        borderColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: borderColor, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(word['Word'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(word['Symbol'] as String? ?? '', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          const Spacer(),
          Expanded(
            child: Text(
              word['Translate'] as String? ?? '',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              InkWell(
                onTap: () {
                  final text = word['Word'] as String? ?? '';
                  TtsService.instance.speak(text);
                },
                child: Icon(Icons.volume_up_outlined, size: 16, color: Colors.grey[400]),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () async {
                  final wordId = word['WordId'] as String;
                  await WordBookProvider.instance.collectWord(wordId, !isCollected);
                  onCollectChanged();
                },
                child: Icon(
                  isCollected ? Icons.star : Icons.star_border,
                  size: 16,
                  color: isCollected ? Colors.amber : Colors.grey[400],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

