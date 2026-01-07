import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/translation_service.dart';
import '../../services/tts_service.dart';
import '../../providers/word_book_provider.dart';

/// Query word dialog with translation functionality
class QueryWordDialog extends StatefulWidget {
  final String? initialWord;

  const QueryWordDialog({super.key, this.initialWord});

  static Future<void> show(BuildContext context, {String? initialWord}) {
    return showDialog(
      context: context,
      builder: (ctx) => QueryWordDialog(initialWord: initialWord),
    );
  }

  @override
  State<QueryWordDialog> createState() => _QueryWordDialogState();
}

class _QueryWordDialogState extends State<QueryWordDialog> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  WordDefinition? _result;
  bool _isLoading = false;
  bool _isWordMode = true; // true = 查词, false = 翻译
  String _translationResult = '';
  final List<String> _searchHistory = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialWord != null && widget.initialWord!.isNotEmpty) {
      _controller.text = widget.initialWord!;
      _doSearch();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _doSearch() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _result = null;
      _translationResult = '';
    });

    // Add to history
    if (!_searchHistory.contains(query)) {
      _searchHistory.insert(0, query);
      if (_searchHistory.length > 10) {
        _searchHistory.removeLast();
      }
    }

    if (_isWordMode) {
      final result = await TranslationService.instance.lookupWord(query);
      if (mounted) {
        setState(() {
          _result = result;
          _isLoading = false;
        });
      }
    } else {
      final result = await TranslationService.instance.translateText(query);
      if (mounted) {
        setState(() {
          _translationResult = result;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _playAudio(String text) async {
    await TtsService.instance.speak(text);
  }

  void _addToWordBook() async {
    if (_result == null) return;

    final provider = Provider.of<WordBookProvider>(context, listen: false);
    final books = provider.books;

    if (books.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有可用的词书，请先创建词书')),
      );
      return;
    }

    // Show book selection dialog
    final selectedBook = await showDialog<WordBook>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择词书'),
        content: SizedBox(
          width: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              return ListTile(
                leading: const Icon(Icons.book),
                title: Text(book.bookName),
                subtitle: Text('${book.wordCount} 词'),
                onTap: () => Navigator.pop(ctx, book),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
        ],
      ),
    );

    if (selectedBook != null && mounted) {
      // Add word to the selected book
      final success = await provider.addWordToBook(
        bookId: selectedBook.bookId,
        word: _result!.word,
        translation: _result!.definitions.isNotEmpty
            ? _result!.definitions.join('; ')
            : _result!.translation,
        phonetic: _result!.phoneticUs,
        example: _result!.examples.isNotEmpty ? _result!.examples.first : '',
        exampleTranslation: _result!.exampleTranslations.isNotEmpty
            ? _result!.exampleTranslations.first
            : '',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? '已添加 "${_result!.word}" 到 ${selectedBook.bookName}'
                : '添加失败，单词可能已存在'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 560,
        constraints: const BoxConstraints(maxHeight: 650),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            _buildSearchBar(),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              )
            else if (_isWordMode && _result != null)
              Flexible(child: _buildWordResult())
            else if (!_isWordMode && _translationResult.isNotEmpty)
              _buildTranslationResult()
            else if (_controller.text.isEmpty && _searchHistory.isNotEmpty)
              _buildHistorySection()
            else if (_controller.text.isNotEmpty && !_isLoading)
              _buildEmptyState(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF3C8CE7), Color(0xFF00EAFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          // Mode toggle
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildModeButton('查词', true),
                _buildModeButton('翻译', false),
              ],
            ),
          ),
          const Spacer(),
          // Data source indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud, size: 14, color: Colors.white),
                SizedBox(width: 4),
                Text('有道 + 金山', style: TextStyle(color: Colors.white, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white),
            tooltip: '关闭',
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton(String label, bool isWord) {
    final isSelected = _isWordMode == isWord;
    return GestureDetector(
      onTap: () {
        setState(() {
          _isWordMode = isWord;
          _result = null;
          _translationResult = '';
        });
        if (_controller.text.isNotEmpty) {
          _doSearch();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF3C8CE7) : Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: _isWordMode ? '输入要查询的单词...' : '输入要翻译的文本...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _controller.clear();
                          setState(() {
                            _result = null;
                            _translationResult = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onSubmitted: (_) => _doSearch(),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _doSearch,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3C8CE7),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('查询'),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text('搜索历史', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() => _searchHistory.clear()),
                child: const Text('清空', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _searchHistory.map((word) {
              return ActionChip(
                label: Text(word),
                onPressed: () {
                  _controller.text = word;
                  _doSearch();
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildWordResult() {
    final r = _result!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Word header with phonetics
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                r.word,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () => _playAudio(r.word),
                icon: const Icon(Icons.volume_up, color: Color(0xFF3C8CE7)),
                tooltip: '发音',
              ),
              const Spacer(),
              IconButton(
                onPressed: _addToWordBook,
                icon: const Icon(Icons.add_circle, color: Color(0xFF4CAF50)),
                tooltip: '添加到词库',
              ),
            ],
          ),

          // Phonetics row
          if (r.phoneticUs.isNotEmpty || r.phoneticUk.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                if (r.phoneticUk.isNotEmpty)
                  InkWell(
                    onTap: () => _playAudio(r.word),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.volume_up, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text('英 /${r.phoneticUk}/', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                if (r.phoneticUs.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () => _playAudio(r.word),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.volume_up, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text('美 /${r.phoneticUs}/', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Chinese definitions section
          if (r.definitions.isNotEmpty) ...[
            _buildSectionLabel('中文释义', const Color(0xFFFF9800)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: r.definitions.map((def) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF9800),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(def, style: const TextStyle(fontSize: 15, height: 1.4)),
                      ),
                    ],
                  ),
                )).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // English definitions section
          if (r.definitionsEn.isNotEmpty) ...[
            _buildSectionLabel('英文释义', const Color(0xFF3C8CE7)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: r.definitionsEn.take(3).map((def) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(def, style: const TextStyle(fontSize: 14, height: 1.4, color: Color(0xFF1565C0))),
                )).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Examples section with translations
          if (r.examples.isNotEmpty) ...[
            _buildSectionLabel('双语例句', const Color(0xFF4CAF50)),
            const SizedBox(height: 8),
            ...List.generate(r.examples.length, (index) {
              final example = r.examples[index];
              final translation = index < r.exampleTranslations.length
                  ? r.exampleTranslations[index]
                  : '';
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFC8E6C9)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          onTap: () => _playAudio(example),
                          child: Icon(Icons.play_circle_outline, size: 18, color: Colors.green[600]),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            example,
                            style: const TextStyle(fontSize: 14, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                    if (translation.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.only(left: 26),
                        child: Text(
                          translation,
                          style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.4),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildTranslationResult() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel('翻译结果', const Color(0xFF4CAF50)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              _translationResult,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _playAudio(_translationResult),
                icon: const Icon(Icons.volume_up, size: 16),
                label: const Text('朗读'),
              ),
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _translationResult));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已复制到剪贴板')),
                  );
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('复制'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.search_off, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 8),
          Text('未找到结果', style: TextStyle(color: Colors.grey[500])),
          const SizedBox(height: 4),
          Text('请检查拼写或尝试其他单词', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
        ],
      ),
    );
  }
}
