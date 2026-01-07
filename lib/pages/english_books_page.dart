import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/english_book_service.dart';
import '../services/translation_service.dart';
import '../services/tts_service.dart';

/// 英语书籍页面
class EnglishBooksPage extends StatefulWidget {
  const EnglishBooksPage({super.key});

  @override
  State<EnglishBooksPage> createState() => _EnglishBooksPageState();
}

class _EnglishBooksPageState extends State<EnglishBooksPage> {
  List<EnglishBook> _books = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    setState(() => _isLoading = true);
    final books = await EnglishBookService.instance.getBooks();
    if (mounted) {
      setState(() {
        _books = books;
        _isLoading = false;
      });
    }
  }

  Future<void> _importBook() async {
    try {
      const XTypeGroup typeGroup = XTypeGroup(
        label: '文本文件',
        extensions: ['txt', 'epub'],
      );

      final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);

      if (file != null) {
        final content = await file.readAsString();
        final fileName = file.name.replaceAll(RegExp(r'\.[^.]+$'), '');

        final bookId = await EnglishBookService.instance.addBook(
          title: fileName,
          content: content,
        );

        if (bookId != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('成功导入 "$fileName"')),
          );
          _loadBooks();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e')),
        );
      }
    }
  }

  void _openReader(EnglishBook book) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookReaderPage(book: book),
      ),
    ).then((_) => _loadBooks());
  }

  Future<void> _deleteBook(EnglishBook book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除书籍'),
        content: Text('确定要删除 "${book.title}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await EnglishBookService.instance.deleteBook(book.bookId);
      _loadBooks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已删除 "${book.title}"')),
        );
      }
    }
  }

  /// 显示在线书籍商店
  void _showOnlineBookStore() {
    // 经典公版英文书籍列表 (来自 Project Gutenberg) - 全部为英语原版
    final onlineBooks = [
      // === 入门级 (简单词汇，适合初学者) ===
      {
        'title': 'Aesop\'s Fables',
        'author': 'Aesop',
        'url': 'https://www.gutenberg.org/cache/epub/11339/pg11339.txt',
        'category': 'Beginner',
        'difficulty': '入门',
      },
      {
        'title': 'The Happy Prince',
        'author': 'Oscar Wilde',
        'url': 'https://www.gutenberg.org/cache/epub/902/pg902.txt',
        'category': 'Beginner',
        'difficulty': '入门',
      },
      {
        'title': 'Peter Pan',
        'author': 'J.M. Barrie',
        'url': 'https://www.gutenberg.org/cache/epub/16/pg16.txt',
        'category': 'Beginner',
        'difficulty': '入门',
      },
      {
        'title': 'The Jungle Book',
        'author': 'Rudyard Kipling',
        'url': 'https://www.gutenberg.org/cache/epub/236/pg236.txt',
        'category': 'Beginner',
        'difficulty': '入门',
      },
      {
        'title': 'Alice in Wonderland',
        'author': 'Lewis Carroll',
        'url': 'https://www.gutenberg.org/cache/epub/11/pg11.txt',
        'category': 'Beginner',
        'difficulty': '入门',
      },
      {
        'title': 'The Wonderful Wizard of Oz',
        'author': 'L. Frank Baum',
        'url': 'https://www.gutenberg.org/cache/epub/55/pg55.txt',
        'category': 'Beginner',
        'difficulty': '入门',
      },
      // === 初级 (适合有基础的读者) ===
      {
        'title': 'The Adventures of Tom Sawyer',
        'author': 'Mark Twain',
        'url': 'https://www.gutenberg.org/cache/epub/74/pg74.txt',
        'category': 'Elementary',
        'difficulty': '初级',
      },
      {
        'title': 'The Call of the Wild',
        'author': 'Jack London',
        'url': 'https://www.gutenberg.org/cache/epub/215/pg215.txt',
        'category': 'Elementary',
        'difficulty': '初级',
      },
      {
        'title': 'Treasure Island',
        'author': 'Robert Louis Stevenson',
        'url': 'https://www.gutenberg.org/cache/epub/120/pg120.txt',
        'category': 'Elementary',
        'difficulty': '初级',
      },
      {
        'title': 'Robinson Crusoe',
        'author': 'Daniel Defoe',
        'url': 'https://www.gutenberg.org/cache/epub/521/pg521.txt',
        'category': 'Elementary',
        'difficulty': '初级',
      },
      {
        'title': 'The Secret Garden',
        'author': 'Frances Hodgson Burnett',
        'url': 'https://www.gutenberg.org/cache/epub/17396/pg17396.txt',
        'category': 'Elementary',
        'difficulty': '初级',
      },
      {
        'title': 'A Christmas Carol',
        'author': 'Charles Dickens',
        'url': 'https://www.gutenberg.org/cache/epub/46/pg46.txt',
        'category': 'Elementary',
        'difficulty': '初级',
      },
      // === 中级 (适合有一定词汇量的读者) ===
      {
        'title': 'The Adventures of Sherlock Holmes',
        'author': 'Arthur Conan Doyle',
        'url': 'https://www.gutenberg.org/cache/epub/1661/pg1661.txt',
        'category': 'Intermediate',
        'difficulty': '中级',
      },
      {
        'title': 'The Hound of the Baskervilles',
        'author': 'Arthur Conan Doyle',
        'url': 'https://www.gutenberg.org/cache/epub/2852/pg2852.txt',
        'category': 'Intermediate',
        'difficulty': '中级',
      },
      {
        'title': 'The Time Machine',
        'author': 'H.G. Wells',
        'url': 'https://www.gutenberg.org/cache/epub/35/pg35.txt',
        'category': 'Intermediate',
        'difficulty': '中级',
      },
      {
        'title': 'The War of the Worlds',
        'author': 'H.G. Wells',
        'url': 'https://www.gutenberg.org/cache/epub/36/pg36.txt',
        'category': 'Intermediate',
        'difficulty': '中级',
      },
      {
        'title': 'The Invisible Man',
        'author': 'H.G. Wells',
        'url': 'https://www.gutenberg.org/cache/epub/5230/pg5230.txt',
        'category': 'Intermediate',
        'difficulty': '中级',
      },
      {
        'title': 'Around the World in Eighty Days',
        'author': 'Jules Verne',
        'url': 'https://www.gutenberg.org/cache/epub/103/pg103.txt',
        'category': 'Intermediate',
        'difficulty': '中级',
      },
      {
        'title': 'Twenty Thousand Leagues Under the Sea',
        'author': 'Jules Verne',
        'url': 'https://www.gutenberg.org/cache/epub/164/pg164.txt',
        'category': 'Intermediate',
        'difficulty': '中级',
      },
      {
        'title': 'Frankenstein',
        'author': 'Mary Shelley',
        'url': 'https://www.gutenberg.org/cache/epub/84/pg84.txt',
        'category': 'Intermediate',
        'difficulty': '中级',
      },
      {
        'title': 'Dracula',
        'author': 'Bram Stoker',
        'url': 'https://www.gutenberg.org/cache/epub/345/pg345.txt',
        'category': 'Intermediate',
        'difficulty': '中级',
      },
      {
        'title': 'The Picture of Dorian Gray',
        'author': 'Oscar Wilde',
        'url': 'https://www.gutenberg.org/cache/epub/174/pg174.txt',
        'category': 'Intermediate',
        'difficulty': '中级',
      },
      // === 高级 (文学经典，词汇丰富) ===
      {
        'title': 'Pride and Prejudice',
        'author': 'Jane Austen',
        'url': 'https://www.gutenberg.org/cache/epub/1342/pg1342.txt',
        'category': 'Advanced',
        'difficulty': '高级',
      },
      {
        'title': 'Sense and Sensibility',
        'author': 'Jane Austen',
        'url': 'https://www.gutenberg.org/cache/epub/161/pg161.txt',
        'category': 'Advanced',
        'difficulty': '高级',
      },
      {
        'title': 'Emma',
        'author': 'Jane Austen',
        'url': 'https://www.gutenberg.org/cache/epub/158/pg158.txt',
        'category': 'Advanced',
        'difficulty': '高级',
      },
      {
        'title': 'Jane Eyre',
        'author': 'Charlotte Bronte',
        'url': 'https://www.gutenberg.org/cache/epub/1260/pg1260.txt',
        'category': 'Advanced',
        'difficulty': '高级',
      },
      {
        'title': 'Wuthering Heights',
        'author': 'Emily Bronte',
        'url': 'https://www.gutenberg.org/cache/epub/768/pg768.txt',
        'category': 'Advanced',
        'difficulty': '高级',
      },
      {
        'title': 'Great Expectations',
        'author': 'Charles Dickens',
        'url': 'https://www.gutenberg.org/cache/epub/1400/pg1400.txt',
        'category': 'Advanced',
        'difficulty': '高级',
      },
      {
        'title': 'Oliver Twist',
        'author': 'Charles Dickens',
        'url': 'https://www.gutenberg.org/cache/epub/730/pg730.txt',
        'category': 'Advanced',
        'difficulty': '高级',
      },
      {
        'title': 'A Tale of Two Cities',
        'author': 'Charles Dickens',
        'url': 'https://www.gutenberg.org/cache/epub/98/pg98.txt',
        'category': 'Advanced',
        'difficulty': '高级',
      },
      {
        'title': 'The Adventures of Huckleberry Finn',
        'author': 'Mark Twain',
        'url': 'https://www.gutenberg.org/cache/epub/76/pg76.txt',
        'category': 'Advanced',
        'difficulty': '高级',
      },
      {
        'title': 'Moby Dick',
        'author': 'Herman Melville',
        'url': 'https://www.gutenberg.org/cache/epub/2701/pg2701.txt',
        'category': 'Advanced',
        'difficulty': '高级',
      },
      {
        'title': 'The Scarlet Letter',
        'author': 'Nathaniel Hawthorne',
        'url': 'https://www.gutenberg.org/cache/epub/25344/pg25344.txt',
        'category': 'Advanced',
        'difficulty': '高级',
      },
      {
        'title': 'Little Women',
        'author': 'Louisa May Alcott',
        'url': 'https://www.gutenberg.org/cache/epub/514/pg514.txt',
        'category': 'Advanced',
        'difficulty': '高级',
      },
      {
        'title': 'The Count of Monte Cristo',
        'author': 'Alexandre Dumas',
        'url': 'https://www.gutenberg.org/cache/epub/1184/pg1184.txt',
        'category': 'Advanced',
        'difficulty': '高级',
      },
      {
        'title': 'Crime and Punishment',
        'author': 'Fyodor Dostoevsky',
        'url': 'https://www.gutenberg.org/cache/epub/2554/pg2554.txt',
        'category': 'Advanced',
        'difficulty': '高级',
      },
      {
        'title': 'Anna Karenina',
        'author': 'Leo Tolstoy',
        'url': 'https://www.gutenberg.org/cache/epub/1399/pg1399.txt',
        'category': 'Advanced',
        'difficulty': '高级',
      },
      {
        'title': 'War and Peace',
        'author': 'Leo Tolstoy',
        'url': 'https://www.gutenberg.org/cache/epub/2600/pg2600.txt',
        'category': 'Advanced',
        'difficulty': '高级',
      },
    ];

    showDialog(
      context: context,
      builder: (ctx) => _OnlineBookStoreDialog(
        books: onlineBooks,
        onDownload: (book) async {
          Navigator.pop(ctx);
          await _downloadOnlineBook(book);
        },
      ),
    );
  }

  /// 下载在线书籍
  Future<void> _downloadOnlineBook(Map<String, String> book) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text('正在下载 "${book['title']}"...'),
          ],
        ),
        duration: const Duration(seconds: 30),
      ),
    );

    try {
      final response = await http.get(Uri.parse(book['url']!)).timeout(
        const Duration(seconds: 30),
      );

      if (response.statusCode == 200) {
        String content = response.body;

        // 清理 Gutenberg 的头尾文本
        const startMarker = '*** START OF';
        const endMarker = '*** END OF';
        final startIndex = content.indexOf(startMarker);
        final endIndex = content.indexOf(endMarker);

        if (startIndex != -1) {
          final actualStart = content.indexOf('\n', startIndex);
          if (actualStart != -1) {
            content = content.substring(actualStart + 1);
          }
        }
        if (endIndex != -1) {
          content = content.substring(0, endIndex);
        }

        final bookId = await EnglishBookService.instance.addBook(
          title: book['title']!,
          content: content.trim(),
          author: book['author'],
        );

        if (bookId != null && mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('成功下载 "${book['title']}"'),
              backgroundColor: Colors.green,
            ),
          );
          _loadBooks();
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('下载失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Content Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
          ),
          child: Row(
            children: [
              Text(
                '英语书籍',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_books.length}',
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _showOnlineBookStore,
                icon: const Icon(Icons.cloud_download_outlined, size: 18),
                label: const Text('在线书库'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _importBook,
                icon: const Icon(Icons.file_upload_outlined, size: 18),
                label: const Text('导入书籍'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: Icon(Icons.refresh, size: 20, color: colorScheme.onSurfaceVariant),
                tooltip: '刷新',
                onPressed: _loadBooks,
              ),
            ],
          ),
        ),
        // Book Grid
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _books.isEmpty
                  ? _buildEmptyState(colorScheme)
                  : _buildBookList(colorScheme),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book_outlined, size: 64, color: colorScheme.outlineVariant),
          const SizedBox(height: 16),
          Text(
            '暂无书籍',
            style: TextStyle(fontSize: 18, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text(
            '导入 TXT 格式的英语书籍开始阅读',
            style: TextStyle(fontSize: 14, color: colorScheme.outline),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _importBook,
            icon: const Icon(Icons.file_upload),
            label: const Text('导入书籍'),
          ),
        ],
      ),
    );
  }

  Widget _buildBookList(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.7,
        ),
        itemCount: _books.length + 1,
        itemBuilder: (context, index) {
          if (index == _books.length) {
            return _buildAddBookCard(colorScheme);
          }
          return _buildBookCard(_books[index], colorScheme);
        },
      ),
    );
  }

  Widget _buildBookCard(EnglishBook book, ColorScheme colorScheme) {
    return InkWell(
      onTap: () => _openReader(book),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Book Cover
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colorScheme.primaryContainer, colorScheme.tertiaryContainer],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    child: Center(
                      child: Icon(Icons.menu_book, size: 48, color: colorScheme.onPrimaryContainer),
                    ),
                  ),
                  // Delete button
                  Positioned(
                    top: 4,
                    right: 4,
                    child: PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, size: 18, color: colorScheme.onPrimaryContainer),
                      onSelected: (value) {
                        if (value == 'delete') {
                          _deleteBook(book);
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, size: 18, color: Colors.red[400]),
                              const SizedBox(width: 8),
                              Text('删除', style: TextStyle(color: Colors.red[400])),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Book Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      book.author,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    if (book.currentPosition > 0)
                      Row(
                        children: [
                          Icon(Icons.bookmark, size: 14, color: colorScheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            '继续阅读',
                            style: TextStyle(fontSize: 11, color: colorScheme.primary),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddBookCard(ColorScheme colorScheme) {
    return InkWell(
      onTap: _importBook,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant, style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, size: 48, color: colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              '导入书籍',
              style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

/// 书籍阅读器页面 - 专业阅读体验
class BookReaderPage extends StatefulWidget {
  final EnglishBook book;

  const BookReaderPage({super.key, required this.book});

  @override
  State<BookReaderPage> createState() => _BookReaderPageState();
}

class _BookReaderPageState extends State<BookReaderPage> {
  bool _isLoading = true;
  String? _selectedWord;
  WordDefinition? _translation;
  bool _isTranslating = false;
  
  // 翻译请求版本号，用于防止旧请求覆盖新请求的结果
  int _translationRequestVersion = 0;

  // 分段内容（用于懒加载渲染）
  List<String> _paragraphs = [];

  // 阅读设置
  double _fontSize = 18;
  double _lineHeight = 1.8;
  int _themeIndex = 0; // 0:白色, 1:米黄, 2:绿豆沙, 3:深色
  bool _showTranslationPanel = true;

  // 章节
  List<Map<String, dynamic>> _chapters = [];
  int _currentChapterIndex = 0;

  // 滚动和进度
  final ScrollController _scrollController = ScrollController();
  double _readingProgress = 0;
  int _totalCharacters = 0;

  // 主题配置
  final List<Map<String, dynamic>> _themes = [
    {'name': '白色', 'bg': const Color(0xFFFFFFFF), 'text': const Color(0xFF333333)},
    {'name': '米黄', 'bg': const Color(0xFFF5F0E1), 'text': const Color(0xFF5B4636)},
    {'name': '绿豆沙', 'bg': const Color(0xFFCCE8CF), 'text': const Color(0xFF2D4A3E)},
    {'name': '深色', 'bg': const Color(0xFF1E1E1E), 'text': const Color(0xFFE0E0E0)},
  ];

  @override
  void initState() {
    super.initState();
    _loadReadingSettings();
    _loadContent();
    _scrollController.addListener(_updateProgress);
  }

  /// 加载阅读设置
  Future<void> _loadReadingSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _fontSize = prefs.getDouble('book_fontSize') ?? 18;
        _lineHeight = prefs.getDouble('book_lineHeight') ?? 1.8;
        _themeIndex = prefs.getInt('book_themeIndex') ?? 0;
        _showTranslationPanel = prefs.getBool('book_showTranslationPanel') ?? true;
      });
    }
  }

  /// 保存阅读设置
  Future<void> _saveReadingSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('book_fontSize', _fontSize);
    await prefs.setDouble('book_lineHeight', _lineHeight);
    await prefs.setInt('book_themeIndex', _themeIndex);
    await prefs.setBool('book_showTranslationPanel', _showTranslationPanel);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateProgress);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateProgress() {
    if (_scrollController.hasClients && _scrollController.position.maxScrollExtent > 0) {
      setState(() {
        _readingProgress = _scrollController.offset / _scrollController.position.maxScrollExtent;
      });
    }
  }

  Future<void> _loadContent() async {
    final content = await EnglishBookService.instance.getBookContent(widget.book.bookId);
    if (content != null) {
      _totalCharacters = content.length;
      _chapters = _extractChapters(content);
      // 按段落分割内容，用于懒加载渲染
      _paragraphs = content
          .split(RegExp(r'\n\n+'))
          .where((p) => p.trim().isNotEmpty)
          .toList();
      // 如果段落数太少，按换行符再分割
      if (_paragraphs.length < 10 && content.length > 5000) {
        _paragraphs = content
            .split('\n')
            .where((p) => p.trim().isNotEmpty)
            .toList();
      }
    }
    setState(() {
      _isLoading = false;
    });

    // 恢复阅读位置
    if (widget.book.currentPosition > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(widget.book.currentPosition.toDouble());
        }
      });
    }
  }

  /// 从内容中提取章节
  List<Map<String, dynamic>> _extractChapters(String content) {
    final chapters = <Map<String, dynamic>>[];

    // 匹配常见的章节模式
    final patterns = [
      RegExp(r'^(Chapter|CHAPTER)\s+[IVXLCDM\d]+[.:]\s*(.*)$', multiLine: true),
      RegExp(r'^(PART|Part)\s+[IVXLCDM\d]+[.:]?\s*(.*)$', multiLine: true),
      RegExp(r'^(BOOK|Book)\s+[IVXLCDM\d]+[.:]?\s*(.*)$', multiLine: true),
      RegExp(r'^\s*([IVXLCDM]+)\.\s*(.*)$', multiLine: true),
    ];

    for (final pattern in patterns) {
      final matches = pattern.allMatches(content);
      for (final match in matches) {
        chapters.add({
          'title': match.group(0)?.trim() ?? '',
          'position': match.start,
        });
      }
    }

    // 按位置排序
    chapters.sort((a, b) => (a['position'] as int).compareTo(b['position'] as int));

    // 如果没有找到章节，创建一个默认的
    if (chapters.isEmpty) {
      chapters.add({'title': '开始', 'position': 0});
    }

    return chapters;
  }

  Future<void> _translateWord(String word) async {
    // 清理单词
    final cleanWord = word.replaceAll(RegExp(r'[^\w]'), '').toLowerCase();
    if (cleanWord.isEmpty) return;

    // 增加请求版本号，同时记录当前版本
    _translationRequestVersion++;
    final currentVersion = _translationRequestVersion;

    setState(() {
      _selectedWord = cleanWord;
      _isTranslating = true;
      _translation = null;
    });

    final result = await TranslationService.instance.lookupWord(cleanWord);
    
    // 只有当前请求版本与最新版本匹配时才更新UI
    // 这样可以防止旧请求的结果覆盖新请求的结果
    if (mounted && currentVersion == _translationRequestVersion) {
      setState(() {
        _translation = result;
        _isTranslating = false;
      });
    }
  }

  void _speakWord(String word) {
    TtsService.instance.speak(word);
  }

  void _savePosition() {
    if (_scrollController.hasClients) {
      final position = _scrollController.offset.toInt();
      EnglishBookService.instance.updateReadingPosition(widget.book.bookId, position);
    }
  }

  void _jumpToChapter(int index) {
    if (index < 0 || index >= _chapters.length || !_scrollController.hasClients) return;

    final chapter = _chapters[index];
    final position = chapter['position'] as int;

    // 估算滚动位置 (基于字符位置比例)
    final maxScroll = _scrollController.position.maxScrollExtent;
    final targetScroll = (position / _totalCharacters) * maxScroll;

    _scrollController.animateTo(
      targetScroll.clamp(0, maxScroll),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );

    setState(() => _currentChapterIndex = index);
    Navigator.pop(context); // 关闭章节抽屉
  }

  void _showChapterDrawer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _themes[_themeIndex]['bg'],
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.list, color: _themes[_themeIndex]['text']),
                  const SizedBox(width: 8),
                  Text(
                    '目录 (${_chapters.length}章)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _themes[_themeIndex]['text'],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _chapters.length,
                itemBuilder: (_, index) {
                  final chapter = _chapters[index];
                  final isCurrentChapter = index == _currentChapterIndex;
                  return ListTile(
                    leading: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isCurrentChapter
                            ? const Color(0xFF5B6CFF)
                            : _themes[_themeIndex]['text'].withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: isCurrentChapter ? Colors.white : _themes[_themeIndex]['text'],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      chapter['title'] as String,
                      style: TextStyle(
                        color: _themes[_themeIndex]['text'],
                        fontWeight: isCurrentChapter ? FontWeight.bold : FontWeight.normal,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _jumpToChapter(index),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _themes[_themeIndex]['bg'],
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('阅读设置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _themes[_themeIndex]['text'])),
            const SizedBox(height: 24),

            // 字体大小
            Row(
              children: [
                Text('字体大小', style: TextStyle(color: _themes[_themeIndex]['text'])),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () {
                    setState(() => _fontSize = (_fontSize - 2).clamp(12, 28));
                    _saveReadingSettings();
                  },
                ),
                Text('${_fontSize.toInt()}', style: TextStyle(color: _themes[_themeIndex]['text'], fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () {
                    setState(() => _fontSize = (_fontSize + 2).clamp(12, 28));
                    _saveReadingSettings();
                  },
                ),
              ],
            ),

            // 行间距
            Row(
              children: [
                Text('行间距', style: TextStyle(color: _themes[_themeIndex]['text'])),
                Expanded(
                  child: Slider(
                    value: _lineHeight,
                    min: 1.2,
                    max: 2.5,
                    divisions: 13,
                    onChanged: (v) {
                      setState(() => _lineHeight = v);
                      _saveReadingSettings();
                    },
                  ),
                ),
                Text(_lineHeight.toStringAsFixed(1), style: TextStyle(color: _themes[_themeIndex]['text'])),
              ],
            ),

            const SizedBox(height: 16),

            // 主题选择
            Text('阅读主题', style: TextStyle(color: _themes[_themeIndex]['text'])),
            const SizedBox(height: 12),
            Row(
              children: List.generate(_themes.length, (i) {
                final theme = _themes[i];
                final isSelected = _themeIndex == i;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _themeIndex = i);
                      _saveReadingSettings();
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme['bg'],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF5B6CFF) : Colors.grey.withValues(alpha: 0.3),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text('Aa', style: TextStyle(color: theme['text'], fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(theme['name'], style: TextStyle(fontSize: 10, color: theme['text'])),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(height: 16),

            // 翻译面板开关
            Row(
              children: [
                Text('显示翻译面板', style: TextStyle(color: _themes[_themeIndex]['text'])),
                const Spacer(),
                Switch(
                  value: _showTranslationPanel,
                  onChanged: (v) {
                    setState(() => _showTranslationPanel = v);
                    _saveReadingSettings();
                  },
                  activeColor: const Color(0xFF5B6CFF),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = _themes[_themeIndex];
    final bgColor = theme['bg'] as Color;
    final textColor = theme['text'] as Color;

    return Scaffold(
      backgroundColor: bgColor,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: textColor))
          : Column(
              children: [
                // 顶部栏
                Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 8,
                    right: 8,
                    bottom: 8,
                  ),
                  color: bgColor,
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: textColor),
                        onPressed: () {
                          _savePosition();
                          Navigator.pop(context);
                        },
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.book.title,
                              style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              widget.book.author,
                              style: TextStyle(color: textColor.withValues(alpha: 0.6), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      // 进度显示
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: textColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${(_readingProgress * 100).toStringAsFixed(1)}%',
                          style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.list, color: textColor),
                        tooltip: '目录',
                        onPressed: _showChapterDrawer,
                      ),
                      IconButton(
                        icon: Icon(Icons.settings, color: textColor),
                        tooltip: '设置',
                        onPressed: _showSettingsPanel,
                      ),
                    ],
                  ),
                ),

                // 进度条
                LinearProgressIndicator(
                  value: _readingProgress,
                  backgroundColor: textColor.withValues(alpha: 0.1),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF5B6CFF)),
                  minHeight: 3,
                ),

                // 主内容区
                Expanded(
                  child: Row(
                    children: [
                      // 阅读区域
                      Expanded(
                        flex: _showTranslationPanel ? 2 : 1,
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            if (notification is ScrollEndNotification) {
                              _savePosition();
                            }
                            return false;
                          },
                          // 使用 ListView.builder 懒加载段落，大幅提升大文件性能
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                            itemCount: _paragraphs.length,
                            itemBuilder: (ctx, index) {
                              final paragraph = _paragraphs[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: SelectableText(
                                  paragraph,
                                  style: TextStyle(
                                    fontSize: _fontSize,
                                    height: _lineHeight,
                                    color: textColor,
                                    fontFamily: 'Georgia',
                                  ),
                                  onSelectionChanged: (selection, cause) {
                                    if (selection.baseOffset != selection.extentOffset) {
                                      final start = selection.baseOffset.clamp(0, paragraph.length);
                                      final end = selection.extentOffset.clamp(0, paragraph.length);
                                      if (start < end && end - start < 50) {
                                        final selectedText = paragraph.substring(start, end);
                                        if (selectedText.trim().isNotEmpty) {
                                          final word = selectedText.trim().split(RegExp(r'\s+')).first;
                                          if (word.isNotEmpty && RegExp(r'^[a-zA-Z]+').hasMatch(word)) {
                                            _translateWord(word);
                                          }
                                        }
                                      }
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      // 翻译侧边栏
                      if (_showTranslationPanel)
                        Container(
                          width: 280,
                          decoration: BoxDecoration(
                            color: _themeIndex == 3
                                ? const Color(0xFF2A2A2A)
                                : Colors.white,
                            border: Border(
                              left: BorderSide(
                                color: textColor.withValues(alpha: 0.1),
                              ),
                            ),
                          ),
                          child: _buildTranslationPanel(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTranslationPanel() {
    final isDark = _themeIndex == 3;
    final panelText = isDark ? Colors.white : Colors.black87;

    if (_selectedWord == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.touch_app_outlined, size: 48, color: panelText.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              '选中单词查看翻译',
              style: TextStyle(color: panelText.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 8),
            Text(
              '双击或拖动选择',
              style: TextStyle(color: panelText.withValues(alpha: 0.3), fontSize: 12),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Word header
          Row(
            children: [
              Expanded(
                child: Text(
                  _selectedWord!,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: panelText,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.volume_up, color: Color(0xFF5B6CFF)),
                onPressed: () => _speakWord(_selectedWord!),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_isTranslating)
            const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ))
          else if (_translation != null) ...[
            // Phonetics
            if (_translation!.phoneticUs.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: panelText.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '/${_translation!.phoneticUs}/',
                  style: TextStyle(color: panelText.withValues(alpha: 0.7)),
                ),
              ),
            const SizedBox(height: 16),

            // Definitions
            const Text(
              '释义',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF5B6CFF),
              ),
            ),
            const SizedBox(height: 8),
            ..._translation!.definitions.take(5).map((def) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: TextStyle(color: panelText)),
                  Expanded(
                    child: Text(
                      def,
                      style: TextStyle(fontSize: 14, color: panelText),
                    ),
                  ),
                ],
              ),
            )),

            // Examples
            if (_translation!.examples.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                '例句',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5B6CFF),
                ),
              ),
              const SizedBox(height: 8),
              ..._translation!.examples.take(2).map((ex) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: panelText.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: panelText.withValues(alpha: 0.1)),
                  ),
                  child: Text(
                    ex,
                    style: TextStyle(
                      fontSize: 13,
                      color: panelText.withValues(alpha: 0.8),
                      fontStyle: FontStyle.italic,
                      height: 1.5,
                    ),
                  ),
                ),
              )),
            ],
          ] else
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '未找到翻译',
                  style: TextStyle(color: panelText.withValues(alpha: 0.5)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 在线书店对话框
class _OnlineBookStoreDialog extends StatefulWidget {
  final List<Map<String, String>> books;
  final Function(Map<String, String>) onDownload;

  const _OnlineBookStoreDialog({
    required this.books,
    required this.onDownload,
  });

  @override
  State<_OnlineBookStoreDialog> createState() => _OnlineBookStoreDialogState();
}

class _OnlineBookStoreDialogState extends State<_OnlineBookStoreDialog> {
  String _selectedDifficulty = '全部';
  final List<String> _difficulties = ['全部', '入门', '初级', '中级', '高级'];

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty) {
      case '入门':
        return Colors.green;
      case '初级':
        return Colors.blue;
      case '中级':
        return Colors.orange;
      case '高级':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredBooks = _selectedDifficulty == '全部'
        ? widget.books
        : widget.books.where((b) => b['difficulty'] == _selectedDifficulty).toList();

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.cloud_download, color: Color(0xFF5B6CFF)),
          const SizedBox(width: 8),
          const Text('在线书库'),
          const Spacer(),
          Text('${filteredBooks.length}本', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: SizedBox(
        width: 600,
        height: 500,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '来自 Project Gutenberg 的公版英文书籍（全部为英语原版）',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            // 难度筛选
            Wrap(
              spacing: 8,
              children: _difficulties.map((d) {
                final isSelected = _selectedDifficulty == d;
                return ChoiceChip(
                  label: Text(d),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _selectedDifficulty = d),
                  selectedColor: d == '全部' ? const Color(0xFF5B6CFF) : _getDifficultyColor(d).withValues(alpha: 0.3),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: filteredBooks.length,
                itemBuilder: (context, index) {
                  final book = filteredBooks[index];
                  final difficulty = book['difficulty'] ?? '';
                  final diffColor = _getDifficultyColor(difficulty);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Container(
                        width: 40,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [diffColor.withValues(alpha: 0.8), diffColor],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(Icons.menu_book, color: Colors.white, size: 20),
                      ),
                      title: Text(book['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(book['author'] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: diffColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: diffColor.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              difficulty,
                              style: TextStyle(fontSize: 11, color: diffColor, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                      isThreeLine: true,
                      trailing: OutlinedButton.icon(
                        onPressed: () => widget.onDownload(book),
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('下载'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF5B6CFF),
                        ),
                      ),
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
}
