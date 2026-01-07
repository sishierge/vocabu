import 'package:flutter/material.dart';
import '../../services/reading_materials_service.dart';
import '../../services/translation_service.dart';
import '../../services/tts_service.dart';
import '../../providers/word_book_provider.dart';

/// 阅读模式页面
class ReadingPage extends StatefulWidget {
  const ReadingPage({super.key});

  @override
  State<ReadingPage> createState() => _ReadingPageState();
}

class _ReadingPageState extends State<ReadingPage> {
  bool _isLoading = true;
  List<ReadingArticle> _articles = [];
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _loadArticles();
  }

  Future<void> _loadArticles() async {
    await ReadingMaterialsService.instance.initialize();
    if (mounted) {
      setState(() {
        _articles = ReadingMaterialsService.instance.getAllArticles();
        _isLoading = false;
      });
    }
  }

  List<ReadingArticle> get _filteredArticles {
    if (_selectedCategory == null) return _articles;
    return _articles.where((a) => a.category == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final categories = ReadingMaterialsService.instance.getCategories();

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
          '英语阅读',
          style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: colorScheme.primary),
            onPressed: _showAddArticleDialog,
            tooltip: '添加文章',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
          : Column(
              children: [
                // 分类筛选
                if (categories.isNotEmpty)
                  Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildCategoryChip('全部', null),
                        ...categories.map((c) => _buildCategoryChip(c, c)),
                      ],
                    ),
                  ),
                // 文章列表
                Expanded(
                  child: _filteredArticles.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredArticles.length,
                          itemBuilder: (context, index) =>
                              _buildArticleCard(_filteredArticles[index]),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildCategoryChip(String label, String? category) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = _selectedCategory == category;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedCategory = category),
        backgroundColor: colorScheme.surfaceContainerHighest,
        selectedColor: colorScheme.primary.withValues(alpha: 0.2),
        labelStyle: TextStyle(
          color: isSelected ? colorScheme.primary : colorScheme.onSurface,
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
          Icon(Icons.menu_book_outlined, size: 64, color: colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            '暂无文章',
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddArticleDialog,
            icon: const Icon(Icons.add),
            label: const Text('添加文章'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArticleCard(ReadingArticle article) {
    final colorScheme = Theme.of(context).colorScheme;
    final markedCount = ReadingMaterialsService.instance.getMarkedWords(article.id).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: () => _openArticle(article),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(article.category).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      article.category,
                      style: TextStyle(
                        color: _getCategoryColor(article.category),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      article.difficulty,
                      style: TextStyle(color: colorScheme.outline, fontSize: 10),
                    ),
                  ),
                  const Spacer(),
                  if (article.isCustom)
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: colorScheme.error, size: 20),
                      onPressed: () => _confirmDelete(article),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                article.title,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${article.content.replaceAll('\n', ' ').substring(
                  0,
                  article.content.length > 100 ? 100 : article.content.length,
                )}...',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 13,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.schedule, size: 14, color: colorScheme.outline),
                  const SizedBox(width: 4),
                  Text(
                    '${article.readingTime} 分钟',
                    style: TextStyle(color: colorScheme.outline, fontSize: 12),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.text_fields, size: 14, color: colorScheme.outline),
                  const SizedBox(width: 4),
                  Text(
                    '${article.wordCount} 词',
                    style: TextStyle(color: colorScheme.outline, fontSize: 12),
                  ),
                  if (markedCount > 0) ...[
                    const SizedBox(width: 16),
                    Icon(Icons.bookmark, size: 14, color: colorScheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      '$markedCount 生词',
                      style: TextStyle(color: colorScheme.primary, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case '科技': return Colors.blue;
      case '旅行': return Colors.green;
      case '科学': return Colors.purple;
      case '文化': return Colors.orange;
      case '健康': return Colors.red;
      case '商业': return Colors.teal;
      default: return Colors.grey;
    }
  }

  void _openArticle(ReadingArticle article) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ArticleReadingPage(article: article),
      ),
    ).then((_) => _loadArticles());
  }

  void _showAddArticleDialog() {
    final colorScheme = Theme.of(context).colorScheme;
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    String category = '自定义';
    String difficulty = '中级';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 500,
            constraints: const BoxConstraints(maxHeight: 600),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.article, color: colorScheme.primary),
                    const SizedBox(width: 12),
                    Text(
                      '添加阅读文章',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: '文章标题',
                    hintText: '例如：The Future of Technology',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: category,
                        decoration: InputDecoration(
                          labelText: '分类',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: ['自定义', '科技', '旅行', '科学', '文化', '健康', '商业']
                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) => setDialogState(() => category = v!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: difficulty,
                        decoration: InputDecoration(
                          labelText: '难度',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: ['初级', '中级', '高级']
                            .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                            .toList(),
                        onChanged: (v) => setDialogState(() => difficulty = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: TextField(
                    controller: contentController,
                    maxLines: 10,
                    decoration: InputDecoration(
                      labelText: '文章内容',
                      hintText: '粘贴英文文章内容...\n\n段落之间用空行分隔',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () async {
                        final title = titleController.text.trim();
                        final content = contentController.text.trim();

                        if (title.isEmpty || content.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('请填写标题和内容')),
                          );
                          return;
                        }

                        final navigator = Navigator.of(context);

                        await ReadingMaterialsService.instance.addArticle(
                          title: title,
                          content: content,
                          category: category,
                          difficulty: difficulty,
                        );

                        if (mounted) {
                          navigator.pop();
                          _loadArticles();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                      ),
                      child: const Text('添加'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(ReadingArticle article) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除文章'),
        content: Text('确定要删除"${article.title}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);

              await ReadingMaterialsService.instance.deleteArticle(article.id);
              if (mounted) {
                navigator.pop();
                _loadArticles();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

/// 文章阅读页面
class _ArticleReadingPage extends StatefulWidget {
  final ReadingArticle article;

  const _ArticleReadingPage({required this.article});

  @override
  State<_ArticleReadingPage> createState() => _ArticleReadingPageState();
}

class _ArticleReadingPageState extends State<_ArticleReadingPage> {
  final ScrollController _scrollController = ScrollController();
  bool _showTranslation = false;
  double _fontSize = 16;
  OverlayEntry? _wordPopup;

  @override
  void dispose() {
    _scrollController.dispose();
    _wordPopup?.remove();
    super.dispose();
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
          widget.article.title,
          style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // 字体大小
          IconButton(
            icon: Icon(Icons.text_decrease, color: colorScheme.onSurfaceVariant),
            onPressed: () => setState(() => _fontSize = (_fontSize - 2).clamp(12, 24)),
          ),
          IconButton(
            icon: Icon(Icons.text_increase, color: colorScheme.onSurfaceVariant),
            onPressed: () => setState(() => _fontSize = (_fontSize + 2).clamp(12, 24)),
          ),
          // 生词列表
          IconButton(
            icon: Icon(Icons.bookmark_border, color: colorScheme.primary),
            onPressed: _showMarkedWords,
            tooltip: '生词列表',
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () {
          _wordPopup?.remove();
          _wordPopup = null;
        },
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              Text(
                widget.article.title,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: _fontSize + 6,
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              // 元信息
              Row(
                children: [
                  _buildInfoChip(Icons.schedule, '${widget.article.readingTime} 分钟'),
                  const SizedBox(width: 12),
                  _buildInfoChip(Icons.text_fields, '${widget.article.wordCount} 词'),
                  const SizedBox(width: 12),
                  _buildInfoChip(Icons.category, widget.article.category),
                ],
              ),
              const SizedBox(height: 24),
              Divider(color: colorScheme.outlineVariant),
              const SizedBox(height: 24),
              // 文章内容
              ...widget.article.paragraphs.map((paragraph) => Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: _buildParagraph(paragraph),
              )),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
      // 底部控制栏
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.outline),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildParagraph(String paragraph) {
    final colorScheme = Theme.of(context).colorScheme;
    final words = paragraph.split(RegExp(r'(\s+)'));

    return Wrap(
      spacing: 0,
      runSpacing: 4,
      children: words.map((segment) {
        // 空白字符直接返回
        if (segment.trim().isEmpty) {
          return Text(' ', style: TextStyle(fontSize: _fontSize));
        }

        // 提取纯单词（去除标点）
        final wordMatch = RegExp(r"([a-zA-Z'-]+)").firstMatch(segment);
        final pureWord = wordMatch?.group(1)?.toLowerCase() ?? '';
        final isMarked = pureWord.isNotEmpty &&
            ReadingMaterialsService.instance.isWordMarked(widget.article.id, pureWord);

        return GestureDetector(
          onTap: () {
            if (pureWord.isNotEmpty) {
              _showWordLookup(pureWord, segment);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            decoration: isMarked
                ? BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  )
                : null,
            child: Text(
              segment,
              style: TextStyle(
                color: isMarked ? colorScheme.primary : colorScheme.onSurface,
                fontSize: _fontSize,
                height: 1.8,
                fontWeight: isMarked ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showWordLookup(String word, String originalText) async {
    _wordPopup?.remove();

    final colorScheme = Theme.of(context).colorScheme;
    final isMarked = ReadingMaterialsService.instance.isWordMarked(widget.article.id, word);

    _wordPopup = OverlayEntry(
      builder: (context) => Positioned(
        top: 100,
        left: 20,
        right: 20,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(16),
          color: colorScheme.surfaceContainer,
          child: Container(
            constraints: const BoxConstraints(maxHeight: 400),
            child: _WordLookupCard(
              word: word,
              articleId: widget.article.id,
              isMarked: isMarked,
              onClose: () {
                _wordPopup?.remove();
                _wordPopup = null;
              },
              onMarkChanged: () => setState(() {}),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_wordPopup!);
  }

  Widget _buildBottomBar() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // 朗读段落
            IconButton(
              icon: Icon(Icons.volume_up, color: colorScheme.primary),
              onPressed: _speakCurrentParagraph,
              tooltip: '朗读',
            ),
            const SizedBox(width: 8),
            // 翻译开关
            TextButton.icon(
              onPressed: () => setState(() => _showTranslation = !_showTranslation),
              icon: Icon(
                _showTranslation ? Icons.translate : Icons.translate_outlined,
                size: 18,
              ),
              label: Text(_showTranslation ? '隐藏翻译' : '显示翻译'),
              style: TextButton.styleFrom(
                foregroundColor: _showTranslation ? colorScheme.primary : colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            // 生词统计
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.bookmark, size: 16, color: colorScheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    '${ReadingMaterialsService.instance.getMarkedWords(widget.article.id).length} 生词',
                    style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _speakCurrentParagraph() async {
    // 朗读第一段或选中的文本
    if (widget.article.paragraphs.isNotEmpty) {
      await TtsService.instance.speak(widget.article.paragraphs.first);
    }
  }

  void _showMarkedWords() {
    final colorScheme = Theme.of(context).colorScheme;
    final markedWords = ReadingMaterialsService.instance.getMarkedWords(widget.article.id);

    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        constraints: const BoxConstraints(maxHeight: 500),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.bookmark, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Text(
                    '生词列表 (${markedWords.length})',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (markedWords.isNotEmpty)
                    TextButton(
                      onPressed: () => _addAllToWordBook(markedWords),
                      child: const Text('全部加入词书'),
                    ),
                ],
              ),
            ),
            Divider(color: colorScheme.outlineVariant, height: 1),
            Expanded(
              child: markedWords.isEmpty
                  ? Center(
                      child: Text(
                        '点击文章中的单词可标记为生词',
                        style: TextStyle(color: colorScheme.outline),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: markedWords.length,
                      itemBuilder: (context, index) {
                        final word = markedWords[index];
                        return ListTile(
                          title: Text(word),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () => _addToWordBook(word),
                                tooltip: '加入词书',
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () async {
                                  final navigator = Navigator.of(context);

                                  await ReadingMaterialsService.instance
                                      .unmarkWord(widget.article.id, word);
                                  navigator.pop();
                                  setState(() {});
                                  _showMarkedWords();
                                },
                                tooltip: '移除',
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addToWordBook(String word) async {
    final provider = WordBookProvider.instance;
    final currentBook = provider.books.firstOrNull;

    if (currentBook == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先创建或选择一个词书')),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    // 查询单词释义
    final definition = await TranslationService.instance.lookupWord(word);

    if (definition != null && mounted) {
      await provider.addWordToBook(
        bookId: currentBook.bookId,
        word: word,
        translation: definition.translation,
        phonetic: definition.phoneticUs,
      );

      messenger.showSnackBar(
        SnackBar(content: Text('已将 "$word" 加入词书')),
      );
    }
  }

  Future<void> _addAllToWordBook(List<String> words) async {
    final provider = WordBookProvider.instance;
    final currentBook = provider.books.firstOrNull;

    if (currentBook == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先创建或选择一个词书')),
      );
      return;
    }

    int added = 0;
    for (final word in words) {
      final definition = await TranslationService.instance.lookupWord(word);
      if (definition != null) {
        await provider.addWordToBook(
          bookId: currentBook.bookId,
          word: word,
          translation: definition.translation,
          phonetic: definition.phoneticUs,
        );
        added++;
      }
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已将 $added 个生词加入词书')),
      );
    }
  }
}

/// 单词查询卡片
class _WordLookupCard extends StatefulWidget {
  final String word;
  final String articleId;
  final bool isMarked;
  final VoidCallback onClose;
  final VoidCallback onMarkChanged;

  const _WordLookupCard({
    required this.word,
    required this.articleId,
    required this.isMarked,
    required this.onClose,
    required this.onMarkChanged,
  });

  @override
  State<_WordLookupCard> createState() => _WordLookupCardState();
}

class _WordLookupCardState extends State<_WordLookupCard> {
  WordDefinition? _definition;
  bool _isLoading = true;
  late bool _isMarked;

  @override
  void initState() {
    super.initState();
    _isMarked = widget.isMarked;
    _lookupWord();
  }

  Future<void> _lookupWord() async {
    final result = await TranslationService.instance.lookupWord(widget.word);
    if (mounted) {
      setState(() {
        _definition = result;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题栏
          Row(
            children: [
              Expanded(
                child: Text(
                  _definition?.word ?? widget.word,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // 标记按钮
              IconButton(
                icon: Icon(
                  _isMarked ? Icons.bookmark : Icons.bookmark_border,
                  color: _isMarked ? colorScheme.primary : colorScheme.outline,
                ),
                onPressed: _toggleMark,
                tooltip: _isMarked ? '取消标记' : '标记为生词',
              ),
              // 加入词书
              IconButton(
                icon: Icon(Icons.add_circle_outline, color: colorScheme.primary),
                onPressed: _addToWordBook,
                tooltip: '加入词书',
              ),
              // 朗读
              IconButton(
                icon: Icon(Icons.volume_up, color: colorScheme.onSurfaceVariant),
                onPressed: () => TtsService.instance.speak(widget.word),
              ),
              IconButton(
                icon: Icon(Icons.close, color: colorScheme.outline),
                onPressed: widget.onClose,
              ),
            ],
          ),
          // 音标
          if (_definition?.phoneticUs.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'US: /${_definition!.phoneticUs}/',
                style: TextStyle(color: colorScheme.outline, fontSize: 14),
              ),
            ),
          const SizedBox(height: 16),
          // 加载中
          if (_isLoading)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: CircularProgressIndicator(color: colorScheme.primary),
              ),
            )
          else if (_definition != null) ...[
            // 中文释义
            if (_definition!.translation.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _definition!.translation,
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontSize: 16,
                  ),
                ),
              ),
            // 英文释义
            if (_definition!.definitionsEn.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '英文释义',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              ..._definition!.definitionsEn.take(3).map((def) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• $def',
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
                ),
              )),
            ],
            // 例句
            if (_definition!.examples.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '例句',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              ..._definition!.examples.take(2).toList().asMap().entries.map((entry) {
                final idx = entry.key;
                final example = entry.value;
                final trans = idx < _definition!.exampleTranslations.length
                    ? _definition!.exampleTranslations[idx]
                    : '';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        example,
                        style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
                      ),
                      if (trans.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          trans,
                          style: TextStyle(color: colorScheme.outline, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                );
              }),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _toggleMark() async {
    if (_isMarked) {
      await ReadingMaterialsService.instance.unmarkWord(widget.articleId, widget.word);
    } else {
      await ReadingMaterialsService.instance.markWord(widget.articleId, widget.word);
    }
    setState(() => _isMarked = !_isMarked);
    widget.onMarkChanged();
  }

  Future<void> _addToWordBook() async {
    final provider = WordBookProvider.instance;
    final currentBook = provider.books.firstOrNull;

    if (currentBook == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先创建或选择一个词书')),
      );
      return;
    }

    if (_definition != null) {
      await provider.addWordToBook(
        bookId: currentBook.bookId,
        word: widget.word,
        translation: _definition!.translation,
        phonetic: _definition!.phoneticUs,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已将 "${widget.word}" 加入词书')),
        );
      }
    }
  }
}
